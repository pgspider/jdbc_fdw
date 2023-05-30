/*
 * --------------------------------------------- jq.c Implementation of Low
 * level JDBC based functions replacing the libpq-fe functions
 *
 * Heimir Sverrisson, 2015-04-13
 *
 * Portions Copyright (c) 2021, TOSHIBA CORPORATION
 *
 * ---------------------------------------------
 */
#include "postgres.h"
#include "jdbc_fdw.h"
#include "catalog/pg_foreign_server.h"
#include "catalog/pg_foreign_table.h"
#include "catalog/pg_user_mapping.h"
#include "catalog/pg_type.h"
#include "storage/ipc.h"
#include "utils/builtins.h"
#include "utils/datetime.h"
#include "utils/guc.h"
#include "utils/syscache.h"
#include "utils/lsyscache.h"
#include "utils/memutils.h"
#include "foreign/fdwapi.h"
#include "funcapi.h"
#include "miscadmin.h"
#include "commands/defrem.h"
#include "libpq-fe.h"

#include "jni.h"

#define Str(arg) #arg
#define StrValue(arg) Str(arg)
#define STR_PKGLIBDIR StrValue(PKG_LIB_DIR)
/* Number of days from unix epoch time (1970-01-01) to postgres epoch time (2000-01-01) */
#define POSTGRES_TO_UNIX_EPOCH_DAYS 		(POSTGRES_EPOCH_JDATE - UNIX_EPOCH_JDATE)
/* POSTGRES_TO_UNIX_EPOCH_DAYS to microseconds */
#define POSTGRES_TO_UNIX_EPOCH_USECS 		(POSTGRES_TO_UNIX_EPOCH_DAYS * USECS_PER_DAY)

#define JNI_VERSION JNI_VERSION_1_2

/*
 * Local housekeeping functions and Java objects
 */

static __thread JNIEnv * Jenv = NULL;
static JavaVM * jvm;
jobject		java_call;
static volatile bool InterruptFlag;		/* Used for checking for SIGINT interrupt */

/*
 * Describes the valid options for objects that use this wrapper.
 */
struct jdbcFdwOption
{
	const char *optname;
	Oid			optcontext;		/* Oid of catalog in which option may appear */
};

/*
 * Structure holding options from the foreign server and user mapping
 * definitions
 */
typedef struct JserverOptions
{
	char	   *url;
	char	   *drivername;
	char	   *username;
	char	   *password;
	int			querytimeout;
	char	   *jarfile;
	int			maxheapsize;
}			JserverOptions;

static JserverOptions opts;

/* Local function prototypes */
static int	jdbc_connect_db_complete(Jconn * conn);
void jdbc_jvm_init(const ForeignServer * server, const UserMapping * user);
static void jdbc_get_server_options(JserverOptions * opts, const ForeignServer * f_server, const UserMapping * f_mapping);
static Jconn * jdbc_create_JDBC_connection(const ForeignServer * server, const UserMapping * user);
/*
 * Uses a String object's content to create an instance of C String
 */
static char *jdbc_convert_string_to_cstring(jobject);
/*
 * Convert byte array to Datum
 */
static Datum jdbc_convert_byte_array_to_datum(jbyteArray);
/*
 * Common function to convert Object value to datum
 */
static Datum jdbc_convert_object_to_datum(Oid, int32, jobject);

/*
 * JVM destroy function
 */
static void jdbc_destroy_jvm();

/*
 * JVM attach function
 */
static void jdbc_attach_jvm();

/*
 * JVM detach function
 */
static void jdbc_detach_jvm();

/*
 * Get JNIEnv from JavaVM
 */
static void jdbc_get_jni_env(void);

/*
 * Add classpath to system class loader using reflection
 */
static void jdbc_add_classpath_to_system_class_loader(char *classpath);

/*
 * Get the maximum heap size for JVM by calling Runtime.getRuntime().maxMemory()
 */
static long jdbc_get_max_heap_size();
/*
 * SIGINT interrupt check and process function
 */
static void jdbc_sig_int_interrupt_check_process();

/*
 * clears any exception that is currently being thrown
 */
void		jq_exception_clear(void);

/*
 * check for pending exceptions
 */
void		jq_get_exception(void);

/*
 * get table infomations for importForeignSchema
 */
static List * jq_get_column_infos(Jconn * conn, char *tablename);
static List * jq_get_table_names(Jconn * conn);


static void jq_get_JDBCUtils(Jconn *conn, jclass *JDBCUtilsClass, jobject *JDBCUtilsObject);

/*
 * jdbc_sig_int_interrupt_check_process Checks and processes if SIGINT
 * interrupt occurs
 */
static void
jdbc_sig_int_interrupt_check_process()
{

	if (InterruptFlag == true)
	{
		jclass		JDBCUtilsClass;
		jmethodID	id_cancel;

		JDBCUtilsClass = (*Jenv)->FindClass(Jenv, "JDBCUtils");
		if (JDBCUtilsClass == NULL)
		{
			elog(ERROR, "JDBCUtilsClass is NULL");
		}
		id_cancel = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "cancel",
										 "()V");
		if (id_cancel == NULL)
		{
			elog(ERROR, "id_cancel is NULL");
		}
		jq_exception_clear();
		(*Jenv)->CallObjectMethod(Jenv, java_call, id_cancel);
		jq_get_exception();
		InterruptFlag = false;
		elog(ERROR, "Query has been cancelled");
	}
}

/*
 * jdbc_convert_string_to_cstring Uses a String object passed as a jobject to
 * the function to create an instance of C String.
 */
static char *
jdbc_convert_string_to_cstring(jobject java_cstring)
{
	jclass		JavaString;
	char	   *StringPointer;
	char	   *cString = NULL;

	jdbc_sig_int_interrupt_check_process();

	JavaString = (*Jenv)->FindClass(Jenv, "java/lang/String");
	if (!((*Jenv)->IsInstanceOf(Jenv, java_cstring, JavaString)))
	{
		elog(ERROR, "Object not an instance of String class");
	}

	if (java_cstring != NULL)
	{
		StringPointer = (char *) (*Jenv)->GetStringUTFChars(Jenv,
															(jstring) java_cstring, 0);
		cString = pstrdup(StringPointer);
		(*Jenv)->ReleaseStringUTFChars(Jenv, (jstring) java_cstring, StringPointer);
		(*Jenv)->DeleteLocalRef(Jenv, java_cstring);
	}
	else
	{
		StringPointer = NULL;
	}
	return (cString);
}

/*
 * jdbc_convert_byte_array_to_datum Uses a byte array object passed as a jbyteArray to
 * the function to convert into Datum.
 */
static Datum
jdbc_convert_byte_array_to_datum(jbyteArray byteVal)
{
	Datum		valueDatum;
	jbyte	   *buf = (*Jenv)->GetByteArrayElements(Jenv, byteVal, NULL);
	jsize		size = (*Jenv)->GetArrayLength(Jenv, byteVal);

	jdbc_sig_int_interrupt_check_process();

	if (buf == NULL)
		return 0;

	valueDatum = (Datum) palloc0(size + VARHDRSZ);
	memcpy(VARDATA(valueDatum), buf, size);
	SET_VARSIZE(valueDatum, size + VARHDRSZ);
	return valueDatum;
}

/*
 * jdbc_convert_object_to_datum Convert jobject to Datum value
 */
static Datum
jdbc_convert_object_to_datum(Oid pgtype, int32 pgtypmod, jobject obj)
{
	switch (pgtype)
	{
		case BYTEAOID:
			return jdbc_convert_byte_array_to_datum(obj);
		default:
		{
			/*
			 * By default, data is retrieved as string and then
			 * convert to compatible data types
			 */
			char   *value = jdbc_convert_string_to_cstring(obj);

			if (value != NULL)
				return jdbc_convert_to_pg(pgtype, pgtypmod, value);
			else
				/* Return 0 if value is NULL */
				return 0;
		}
	}
}

/*
 * jdbc_destroy_jvm Shuts down the JVM.
 */
static void
jdbc_destroy_jvm()
{
	ereport(DEBUG3, (errmsg("In jdbc_destroy_jvm")));

	(*jvm)->DestroyJavaVM(jvm);
}

/*
 * jdbc_attach_jvm Attach the JVM.
 */
static void
jdbc_attach_jvm()
{
	ereport(DEBUG3, (errmsg("In jdbc_attach_jvm")));

	(*jvm)->AttachCurrentThread(jvm, (void **) &Jenv, NULL);
}

/*
 * jdbc_detach_jvm Detach the JVM.
 */
static void
jdbc_detach_jvm()
{
	ereport(DEBUG3, (errmsg("In jdbc_detach_jvm")));

	(*jvm)->DetachCurrentThread(jvm);
}

static void jdbc_get_jni_env(void)
{
	int JVMEnvStat;

	ereport(DEBUG3, (errmsg("In jdbc_get_jni_env")));

	JVMEnvStat = (*jvm)->GetEnv(jvm, (void **) &Jenv, JNI_VERSION);
	if (JVMEnvStat == JNI_EDETACHED)
	{
		ereport(DEBUG3, (errmsg("JVMEnvStat: JNI_EDETACHED; the current thread is not attached to the VM")));
		jdbc_attach_jvm();
	}
	else if (JVMEnvStat == JNI_OK)
	{
		ereport(DEBUG3, (errmsg("JVMEnvStat: JNI_OK")));
	}
	else if (JVMEnvStat == JNI_EVERSION)
	{
		ereport(ERROR, (errmsg("JVMEnvStat: JNI_EVERSION; the specified version is not supported")));
	}
}

static void jdbc_add_classpath_to_system_class_loader(char *classpath)
{
	int url_classpath_len;
	char *url_classpath;
	jclass ClassLoader_class;
	jmethodID ClassLoader_getSystemClassLoader;
	jobject system_class_loader;
	jclass URLClassLoader_class;
	jmethodID URLClassLoader_addURL;
	jclass URL_class;
	jmethodID URL_constructor;
	jobject url;

	ereport(DEBUG3, errmsg("In jdbc_add_classpath_to_system_class_loader"));

	url_classpath_len = 5 + strlen(classpath) + 2; /* "file:" + classpath + '/\0' */
	url_classpath = (char *)palloc0(url_classpath_len);
	snprintf(url_classpath, url_classpath_len, "file:%s/", classpath);


	ClassLoader_class = (*Jenv)->FindClass(Jenv, "java/lang/ClassLoader");
	if (ClassLoader_class == NULL) {
		ereport(ERROR, errmsg("java/lang/ClassLoader is not found"));
	}

	ClassLoader_getSystemClassLoader = (*Jenv)->GetStaticMethodID(Jenv, ClassLoader_class,
															   "getSystemClassLoader", "()Ljava/lang/ClassLoader;");
	if (ClassLoader_getSystemClassLoader == NULL) {
		ereport(ERROR, errmsg("ClassLoader.getSystemClassLoader is not found"));
	}

	URLClassLoader_class = (*Jenv)->FindClass(Jenv, "java/net/URLClassLoader");
	if (URLClassLoader_class == NULL) {
		ereport(ERROR, errmsg("java/net/URLClassLoader is not found"));
	}

	URLClassLoader_addURL = (*Jenv)->GetMethodID(Jenv, URLClassLoader_class,
											  "addURL", "(Ljava/net/URL;)V");
	if (URLClassLoader_addURL == NULL) {
		ereport(ERROR, errmsg("URLClassLoader.addURL is not found"));
	}

	URL_class = (*Jenv)->FindClass(Jenv, "java/net/URL");
	if (URL_class == NULL) {
		ereport(ERROR, errmsg("java/net/URL is not found"));
	}

	URL_constructor = (*Jenv)->GetMethodID(Jenv, URL_class,
										"<init>", "(Ljava/lang/String;)V");
	if (URL_constructor == NULL) {
		ereport(ERROR, errmsg("URL.<init> is not found"));
	}

	jq_exception_clear();
	system_class_loader = (*Jenv)->CallStaticObjectMethod(
		Jenv, ClassLoader_class, ClassLoader_getSystemClassLoader);
	jq_get_exception();

	jq_exception_clear();
	url = (*Jenv)->NewObject(Jenv, URL_class, URL_constructor, (*Jenv)->NewStringUTF(Jenv, url_classpath));
	jq_get_exception();

	jq_exception_clear();
	(*Jenv)->CallVoidMethod(Jenv, system_class_loader, URLClassLoader_addURL, url);
	jq_get_exception();

	ereport(DEBUG3, errmsg("Add classpath to System Class Loader: %s", url_classpath));
}

static long jdbc_get_max_heap_size()
{
	jclass Runtime_class;
	jmethodID Runtime_getRuntime;
	jobject runtime;
	jmethodID Runtime_maxMemory;
	jlong max_memory;

	ereport(DEBUG3, errmsg("entering function %s", __func__));

	Runtime_class = (*Jenv)->FindClass(Jenv, "java/lang/Runtime");
	if (Runtime_class == NULL) {
		ereport(ERROR, errmsg("java/lang/Runtime is not found"));
	}

	Runtime_getRuntime = (*Jenv)->GetStaticMethodID(Jenv, Runtime_class, 
												 "getRuntime", "()Ljava/lang/Runtime;");
	if (Runtime_getRuntime  == NULL) {
		ereport(ERROR, errmsg("Runtime.getRuntime is not found"));
	}

	Runtime_maxMemory = (*Jenv)->GetMethodID(Jenv, Runtime_class, "maxMemory", "()J");
	if (Runtime_maxMemory  == NULL) {
		ereport(ERROR, errmsg("Runtime.maxMemory is not found"));
	}

	jq_exception_clear();
	runtime = (*Jenv)->CallStaticObjectMethod(Jenv, Runtime_class,
						 Runtime_getRuntime);
	jq_get_exception();

	jq_exception_clear();
	max_memory = (*Jenv)->CallLongMethod(Jenv, runtime, Runtime_maxMemory);
	jq_get_exception();

	return max_memory;
}

/*
 * jdbc_jvm_init Create the JVM which will be used for calling the Java
 * routines that use JDBC to connect and access the foreign database.
 *
 */
void
jdbc_jvm_init(const ForeignServer * server, const UserMapping * user)
{
	static bool FunctionCallCheck = false;	/* This flag safeguards against
											 * multiple calls of
											 * jdbc_jvm_init() */

	jint		res = -5;		/* Set to a negative value so we can see
								 * whether JVM has been correctly created or
								 * not */
	JavaVMInitArgs vm_args;
	JavaVMOption *options = NULL;
	char		strpkglibdir[] = STR_PKGLIBDIR;
	char	   *maxheapsizeoption = NULL;

	opts.maxheapsize = 0;

	ereport(DEBUG3, (errmsg("In jdbc_jvm_init")));
	jdbc_get_server_options(&opts, server, user);	/* Get the maxheapsize
													 * value (if set) */

	jdbc_sig_int_interrupt_check_process();

	if (FunctionCallCheck == false)
	{
		if (opts.maxheapsize != 0)
		{						/* If the user has given a value for setting
								 * the max heap size of the JVM */
			options = (JavaVMOption *) palloc0(sizeof(JavaVMOption));
			maxheapsizeoption = (char *) palloc0(sizeof(int) + 6);
			snprintf(maxheapsizeoption, sizeof(int) + 6, "-Xmx%dm", opts.maxheapsize);
			options[0].optionString = maxheapsizeoption;
			vm_args.nOptions = 1;
		}
		else
		{
			vm_args.nOptions = 0;
		}
		vm_args.version = JNI_VERSION;
		vm_args.options = options;
		vm_args.ignoreUnrecognized = JNI_FALSE;

		/* Create the Java VM */
		res = JNI_CreateJavaVM(&jvm, (void **) &Jenv, &vm_args);
		if (res == JNI_EEXIST) {
			res = JNI_GetCreatedJavaVMs(&jvm, 1, NULL);
			if (res < 0) {
				ereport(ERROR, errmsg("Failed to get created Java VM"));
			}
			jdbc_get_jni_env();
			jdbc_add_classpath_to_system_class_loader(strpkglibdir);
			ereport(INFO, errmsg("Java VM has already been created by another extension. "
						"The existing Java VM will be re-used. "
						"The max heapsize may be different from the setting value. "
						"The current max heapsize is %ld bytes", jdbc_get_max_heap_size()));
		}
		else if (res < 0)
		{
			ereport(ERROR, (errmsg("Failed to create Java VM")));
		} else {
			ereport(DEBUG3, (errmsg("Successfully created a JVM with %d MB heapsize", opts.maxheapsize)));
			jdbc_add_classpath_to_system_class_loader(strpkglibdir);
		}
		InterruptFlag = false;
		/* Register an on_proc_exit handler that shuts down the JVM. */
		on_proc_exit(jdbc_destroy_jvm, 0);
		FunctionCallCheck = true;
	}
	else
	{
		jdbc_get_jni_env();
	}
}

/*
 * Create an actual JDBC connection to the foreign server. Precondition:
 * jdbc_jvm_init() has been successfully called. Returns: Jconn.status =
 * CONNECTION_OK and a valid reference to a JDBCUtils class Error return:
 * Jconn.status = CONNECTION_BAD
 */
static Jconn *
jdbc_create_JDBC_connection(const ForeignServer * server, const UserMapping * user)
{
	jmethodID	idCreate;
	jstring		stringArray[6];
	jclass		javaString;
	jobjectArray argArray;
	jclass		JDBCUtilsClass;
	jmethodID	idGetIdentifierQuoteString;
	jstring		identifierQuoteString;
	char	   *quote_string;
	char	   *querytimeout_string;
	int			i;
	int			numParams = sizeof(stringArray) / sizeof(jstring);	/* Number of parameters
																	 * to Java */
	int			intSize = 10;	/* The string size to allocate for an integer
								 * value */
	int			keyid = server->serverid;	/* key for the hashtable in java
											 * depends on serverid */
	MemoryContext oldcontext = MemoryContextSwitchTo(TopMemoryContext);	/* Switch the memory context to TopMemoryContext to avoid the
																		 * case connection is released when execution state finished */
	Jconn	   *conn = (Jconn *) palloc0(sizeof(Jconn));

	ereport(DEBUG3, (errmsg("In jdbc_create_JDBC_connection")));
	conn->status = CONNECTION_BAD;
	conn->festate = (jdbcFdwExecutionState *) palloc0(sizeof(jdbcFdwExecutionState));
	conn->festate->query = NULL;
	JDBCUtilsClass = (*Jenv)->FindClass(Jenv, "JDBCUtils");
	if (JDBCUtilsClass == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils class!")));
	}
	idCreate = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "createConnection",
									"(I[Ljava/lang/String;)V");
	if (idCreate == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.createConnection method!")));
	}
	idGetIdentifierQuoteString = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "getIdentifierQuoteString", "()Ljava/lang/String;");
	if (idGetIdentifierQuoteString == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.getIdentifierQuoteString method")));
	}

	/*
	 * Construct the array to pass our parameters Query timeout is an int, we
	 * need a string
	 */
	querytimeout_string = (char *) palloc0(intSize);
	snprintf(querytimeout_string, intSize, "%d", opts.querytimeout);
	stringArray[0] = (*Jenv)->NewStringUTF(Jenv, opts.drivername);
	stringArray[1] = (*Jenv)->NewStringUTF(Jenv, opts.url);
	stringArray[2] = (*Jenv)->NewStringUTF(Jenv, opts.username);
	stringArray[3] = (*Jenv)->NewStringUTF(Jenv, opts.password);
	stringArray[4] = (*Jenv)->NewStringUTF(Jenv, querytimeout_string);
	stringArray[5] = (*Jenv)->NewStringUTF(Jenv, opts.jarfile);
	/* Set up the return value */
	javaString = (*Jenv)->FindClass(Jenv, "java/lang/String");
	argArray = (*Jenv)->NewObjectArray(Jenv, numParams, javaString, stringArray[0]);
	if (argArray == NULL)
	{
		/* Return Java memory */
		for (i = 0; i < numParams; i++)
		{
			(*Jenv)->DeleteLocalRef(Jenv, stringArray[i]);
		}
		ereport(ERROR, (errmsg("Failed to create argument array")));
	}
	for (i = 1; i < numParams; i++)
	{
		(*Jenv)->SetObjectArrayElement(Jenv, argArray, i, stringArray[i]);
	}
	conn->JDBCUtilsObject = (*Jenv)->AllocObject(Jenv, JDBCUtilsClass);
	if (conn->JDBCUtilsObject == NULL)
	{
		/* Return Java memory */
		for (i = 0; i < numParams; i++)
		{
			(*Jenv)->DeleteLocalRef(Jenv, stringArray[i]);
		}
		(*Jenv)->DeleteLocalRef(Jenv, argArray);
		ereport(ERROR, (errmsg("Failed to create java call")));
	}
	jq_exception_clear();
	(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idCreate, keyid, argArray);
	jq_get_exception();
	/* Return Java memory */
	for (i = 0; i < numParams; i++)
	{
		(*Jenv)->DeleteLocalRef(Jenv, stringArray[i]);
	}
	(*Jenv)->DeleteLocalRef(Jenv, argArray);
	ereport(DEBUG3, (errmsg("Created a JDBC connection: %s", opts.url)));
	/* get default identifier quote string */
	jq_exception_clear();
	identifierQuoteString = (jstring) (*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idGetIdentifierQuoteString);
	jq_get_exception();
	quote_string = jdbc_convert_string_to_cstring((jobject) identifierQuoteString);
	conn->q_char = pstrdup(quote_string);
	conn->status = CONNECTION_OK;
	pfree(querytimeout_string);
	/* Switch back to old context */
	MemoryContextSwitchTo(oldcontext);
	return conn;
}

/*
 * Fetch the options for a jdbc_fdw foreign server and user mapping.
 */
static void
jdbc_get_server_options(JserverOptions * opts, const ForeignServer * f_server, const UserMapping * f_mapping)
{
	List	   *options;
	ListCell   *lc;

	/* Collect options from server and user mapping */
	options = NIL;
	options = list_concat(options, f_server->options);
	options = list_concat(options, f_mapping->options);

	/* Loop through the options, and get the values */
	foreach(lc, options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "drivername") == 0)
		{
			opts->drivername = defGetString(def);
		}
		if (strcmp(def->defname, "username") == 0)
		{
			opts->username = defGetString(def);
		}
		if (strcmp(def->defname, "querytimeout") == 0)
		{
			opts->querytimeout = atoi(defGetString(def));
		}
		if (strcmp(def->defname, "jarfile") == 0)
		{
			opts->jarfile = defGetString(def);
		}
		if (strcmp(def->defname, "maxheapsize") == 0)
		{
			opts->maxheapsize = atoi(defGetString(def));
		}
		if (strcmp(def->defname, "password") == 0)
		{
			opts->password = defGetString(def);
		}
		if (strcmp(def->defname, "url") == 0)
		{
			opts->url = defGetString(def);
		}
	}
}

Jresult *
jq_exec(Jconn * conn, const char *query)
{
	jmethodID	idCreateStatement;
	jstring		statement;
	jclass		JDBCUtilsClass;
	jobject		JDBCUtilsObject;
	Jresult    *res;

	ereport(DEBUG3, (errmsg("In jq_exec(%p): %s", conn, query)));

	jq_get_JDBCUtils(conn, &JDBCUtilsClass, &JDBCUtilsObject);

	res = (Jresult *) palloc0(sizeof(Jresult));
	*res = PGRES_FATAL_ERROR;

	idCreateStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "createStatement",
											 "(Ljava/lang/String;)V");
	if (idCreateStatement == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.createStatement method!")));
	}
	/* The query argument */
	statement = (*Jenv)->NewStringUTF(Jenv, query);
	if (statement == NULL)
	{
		ereport(ERROR, (errmsg("Failed to create query argument")));
	}
	jq_exception_clear();
	(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idCreateStatement, statement);
	jq_get_exception();
	/* Return Java memory */
	(*Jenv)->DeleteLocalRef(Jenv, statement);
	*res = PGRES_COMMAND_OK;
	return res;
}

Jresult *
jq_exec_id(Jconn * conn, const char *query, int *resultSetID)
{
	jmethodID	idCreateStatementID;
	jstring		statement;
	jclass		JDBCUtilsClass;
	jobject		JDBCUtilsObject;
	Jresult    *res;

	ereport(DEBUG3, (errmsg("In jq_exec_id(%p): %s", conn, query)));

	jq_get_JDBCUtils(conn, &JDBCUtilsClass, &JDBCUtilsObject);

	res = (Jresult *) palloc0(sizeof(Jresult));
	*res = PGRES_FATAL_ERROR;

	idCreateStatementID = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "createStatementID",
											   "(Ljava/lang/String;)I");
	if (idCreateStatementID == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.createStatementID method!")));
	}
	/* The query argument */
	statement = (*Jenv)->NewStringUTF(Jenv, query);
	if (statement == NULL)
	{
		ereport(ERROR, (errmsg("Failed to create query argument")));
	}
	jq_exception_clear();
	*resultSetID = (int) (*Jenv)->CallIntMethod(Jenv, conn->JDBCUtilsObject, idCreateStatementID, statement);
	jq_get_exception();
	if (*resultSetID < 0)
	{
		/* Return Java memory */
		(*Jenv)->DeleteLocalRef(Jenv, statement);
		ereport(ERROR, (errmsg("Get resultSetID failed with code: %d", *resultSetID)));
	}
	ereport(DEBUG3, (errmsg("Get resultSetID successfully, ID: %d", *resultSetID)));

	/* Return Java memory */
	(*Jenv)->DeleteLocalRef(Jenv, statement);
	*res = PGRES_COMMAND_OK;
	return res;
}

void *
jq_release_resultset_id(Jconn * conn, int resultSetID)
{
	jmethodID	idClearResultSetID;
	jclass		JDBCUtilsClass;
	jobject		JDBCUtilsObject;

	ereport(DEBUG3, (errmsg("In jq_release_resultset_id: %d", resultSetID)));

	jq_get_JDBCUtils(conn, &JDBCUtilsClass, &JDBCUtilsObject);

	idClearResultSetID = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "clearResultSetID",
											  "(I)V");
	if (idClearResultSetID == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.clearResultSetID method!")));
	}
	jq_exception_clear();
	(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idClearResultSetID, resultSetID);
	jq_get_exception();

	return NULL;
}

/*
 * jq_iterate: Read the next row from the remote server
 */
TupleTableSlot *
jq_iterate(Jconn * conn, ForeignScanState * node, List * retrieved_attrs, int resultSetID)
{
	jobject		JDBCUtilsObject;
	TupleTableSlot *tupleSlot = node->ss.ss_ScanTupleSlot;
	TupleDesc	tupleDescriptor = tupleSlot->tts_tupleDescriptor;
	jclass		JDBCUtilsClass;
	jmethodID	idResultSet;
	jmethodID	idNumberOfColumns;
	jobjectArray rowArray;
	char	  **values;
	int			numberOfColumns;
	int			i;

	ereport(DEBUG3, (errmsg("In jq_iterate")));

	memset(tupleSlot->tts_values, 0, sizeof(Datum) * tupleDescriptor->natts);
	memset(tupleSlot->tts_isnull, true, sizeof(bool) * tupleDescriptor->natts);

	jq_get_JDBCUtils(conn, &JDBCUtilsClass, &JDBCUtilsObject);

	ExecClearTuple(tupleSlot);
	jdbc_sig_int_interrupt_check_process();

	idNumberOfColumns = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "getNumberOfColumns", "(I)I");
	if (idNumberOfColumns == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.getNumberOfColumns method")));
	}
	jq_exception_clear();
	numberOfColumns = (int) (*Jenv)->CallIntMethod(Jenv, conn->JDBCUtilsObject, idNumberOfColumns, resultSetID);
	jq_get_exception();
	if (numberOfColumns < 0)
	{
		ereport(ERROR, (errmsg("getNumberOfColumns got wrong value: %d", numberOfColumns)));
	}

	if ((*Jenv)->PushLocalFrame(Jenv, (numberOfColumns + 10)) < 0)
	{
		ereport(ERROR, (errmsg("Error pushing local java frame")));
	}

	idResultSet = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "getResultSet", "(I)[Ljava/lang/Object;");
	if (idResultSet == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.getResultSet method!")));
	}
	/* Allocate pointers to the row data */
	jq_exception_clear();
	rowArray = (*Jenv)->CallObjectMethod(Jenv, JDBCUtilsObject, idResultSet, resultSetID);
	jq_get_exception();
	if (rowArray != NULL)
	{
		if(retrieved_attrs != NIL){

			values = (char **) palloc0(tupleDescriptor->natts * sizeof(char *));
			for (i = 0; i < retrieved_attrs->length; i++)
			{
				int			column_index = retrieved_attrs->elements[i].int_value - 1;
				Oid			pgtype = TupleDescAttr(tupleDescriptor, column_index)->atttypid;
				int32		pgtypmod = TupleDescAttr(tupleDescriptor, column_index)->atttypmod;
				jobject		obj = (jobject) (*Jenv)->GetObjectArrayElement(Jenv, rowArray, i);

				if (obj != NULL)
				{
					tupleSlot->tts_isnull[column_index] = false;
					tupleSlot->tts_values[column_index] = jdbc_convert_object_to_datum(pgtype, pgtypmod, obj);
				}
			}
		}else{
			jsize size = (*Jenv)->GetArrayLength(Jenv, rowArray);
			memset(tupleSlot->tts_values, 0, sizeof(Datum) * (int)size);
			memset(tupleSlot->tts_isnull, true, sizeof(bool) * (int)size);
			ExecClearTuple(tupleSlot);
			values = (char **) palloc0(size * sizeof(char *));
			for (i = 0; i < size; i++)
			{
				values[i] = jdbc_convert_string_to_cstring((jobject) (*Jenv)->GetObjectArrayElement(Jenv, rowArray, i));
				if (values[i] != NULL)
				{
					tupleSlot->tts_isnull[i] = false;
					tupleSlot->tts_values[i] = *values[i];
				}
			}
		}
		ExecStoreVirtualTuple(tupleSlot);
		(*Jenv)->DeleteLocalRef(Jenv, rowArray);
	}
	(*Jenv)->PopLocalFrame(Jenv, NULL);
	return (tupleSlot);
}

/*
 * jq_iterate_all_row: Read the all row from the remote server without an existing foreign table
 */
void
jq_iterate_all_row(FunctionCallInfo fcinfo, Jconn * conn, TupleDesc tupleDescriptor, int resultSetID)
{
	ReturnSetInfo	   *rsinfo = (ReturnSetInfo *) fcinfo->resultinfo;

	jobject				JDBCUtilsObject;
	jclass				JDBCUtilsClass;

	jmethodID			idResultSet;
	jmethodID			idNumberOfColumns;
	jobjectArray		rowArray;

	Tuplestorestate	   *tupstore;
	HeapTuple			tuple;

	MemoryContext		oldcontext;

	Datum			   *values;
	bool			   *nulls;

	int					numberOfColumns;

	ereport(DEBUG3, (errmsg("In jq_iterate_all_row")));

	oldcontext = MemoryContextSwitchTo(rsinfo->econtext->ecxt_per_query_memory);
	tupstore = tuplestore_begin_heap(true, false, work_mem);

	jq_get_JDBCUtils(conn, &JDBCUtilsClass, &JDBCUtilsObject);
	jdbc_sig_int_interrupt_check_process();

	idNumberOfColumns = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "getNumberOfColumns", "(I)I");
	if (idNumberOfColumns == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.getNumberOfColumns method")));
	}
	jq_exception_clear();
	numberOfColumns = (int) (*Jenv)->CallIntMethod(Jenv, conn->JDBCUtilsObject, idNumberOfColumns, resultSetID);
	jq_get_exception();
	if (numberOfColumns < 0)
	{
		ereport(ERROR, (errmsg("getNumberOfColumns got wrong value: %d", numberOfColumns)));
	}

	if ((*Jenv)->PushLocalFrame(Jenv, (numberOfColumns + 10)) < 0)
	{
		ereport(ERROR, (errmsg("Error pushing local java frame")));
	}

	idResultSet = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "getResultSet", "(I)[Ljava/lang/Object;");
	if (idResultSet == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.getResultSet method!")));
	}

	do
	{
		/* Allocate pointers to the row data */
		jq_exception_clear();
		rowArray = (*Jenv)->CallObjectMethod(Jenv, JDBCUtilsObject, idResultSet, resultSetID);
		jq_get_exception();

		if (rowArray != NULL)
		{
			values = (Datum *) palloc0(tupleDescriptor->natts * sizeof(Datum));
			nulls = (bool *) palloc(tupleDescriptor->natts * sizeof(bool));
			/* Initialize to nulls for any columns not present in result */
			memset(nulls, true, tupleDescriptor->natts * sizeof(bool));

			for (int i = 0; i < numberOfColumns; i++)
			{
				int			column_index = i;
				Oid			pgtype = TupleDescAttr(tupleDescriptor, column_index)->atttypid;
				int32		pgtypmod = TupleDescAttr(tupleDescriptor, column_index)->atttypmod;
				jobject		obj = (jobject) (*Jenv)->GetObjectArrayElement(Jenv, rowArray, i);

				if (obj != NULL)
				{
					values[column_index] = jdbc_convert_object_to_datum(pgtype, pgtypmod, obj);
					nulls[column_index] = false;
				}
			}

			tuple = heap_form_tuple(tupleDescriptor, values, nulls);
			tuplestore_puttuple(tupstore, tuple);

			(*Jenv)->DeleteLocalRef(Jenv, rowArray);
		}
	}
	while (rowArray != NULL);

	if (tuple != NULL)
	{
		rsinfo->setResult = tupstore;
		rsinfo->setDesc = tupleDescriptor;
		MemoryContextSwitchTo(oldcontext);
	}

	(*Jenv)->PopLocalFrame(Jenv, NULL);
}



Jresult *
jq_exec_prepared(Jconn * conn, const int *paramLengths,
				 const int *paramFormats, int resultFormat, int resultSetID)
{
	jmethodID	idExecPreparedStatement;
	jclass		JDBCUtilsClass;
	jobject		JDBCUtilsObject;
	Jresult    *res;

	ereport(DEBUG3, (errmsg("In jq_exec_prepared")));

	jq_get_JDBCUtils(conn, &JDBCUtilsClass, &JDBCUtilsObject);

	res = (Jresult *) palloc0(sizeof(Jresult));
	*res = PGRES_FATAL_ERROR;

	idExecPreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "execPreparedStatement",
												   "(I)V");
	if (idExecPreparedStatement == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.execPreparedStatement method!")));
	}
	jq_exception_clear();
	(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idExecPreparedStatement, resultSetID);
	jq_get_exception();

	/* Return Java memory */
	*res = PGRES_COMMAND_OK;

	return res;
}

void
jq_clear(Jresult * res)
{
	ereport(DEBUG3, (errmsg("In jq_clear")));
	pfree(res);
	return;
}

char *
jq_cmd_tuples(Jresult * res)
{
	ereport(DEBUG3, (errmsg("In jq_cmd_tuples")));
	return 0;
}

char *
jq_get_value(const Jresult * res, int tup_num, int field_num)
{
	ereport(DEBUG3, (errmsg("In jq_get_value")));
	return 0;
}

Jresult *
jq_prepare(Jconn * conn, const char *query,
		   const Oid * paramTypes, int *resultSetID)
{
	jmethodID	idCreatePreparedStatement;
	jstring		statement;
	jclass		JDBCUtilsClass;
	jobject		JDBCUtilsObject;
	Jresult    *res;

	ereport(DEBUG3, (errmsg("In jq_prepare(%p): %s", conn, query)));

	jq_get_JDBCUtils(conn, &JDBCUtilsClass, &JDBCUtilsObject);

	res = (Jresult *) palloc0(sizeof(Jresult));
	*res = PGRES_FATAL_ERROR;

	idCreatePreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "createPreparedStatement",
													 "(Ljava/lang/String;)I");
	if (idCreatePreparedStatement == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.createPreparedStatement method!")));
	}
	/* The query argument */
	statement = (*Jenv)->NewStringUTF(Jenv, query);
	if (statement == NULL)
	{
		ereport(ERROR, (errmsg("Failed to create query argument")));
	}
	jq_exception_clear();
	/* get the resultSetID */
	*resultSetID = (int) (*Jenv)->CallIntMethod(Jenv, conn->JDBCUtilsObject, idCreatePreparedStatement, statement);
	jq_get_exception();
	if (*resultSetID < 0)
	{
		/* Return Java memory */
		(*Jenv)->DeleteLocalRef(Jenv, statement);
		ereport(ERROR, (errmsg("Get resultSetID failed with code: %d", *resultSetID)));
	}
	ereport(DEBUG3, (errmsg("Get resultSetID successfully, ID: %d", *resultSetID)));

	/* Return Java memory */
	(*Jenv)->DeleteLocalRef(Jenv, statement);
	*res = PGRES_COMMAND_OK;

	return res;
}

int
jq_nfields(const Jresult * res)
{
	ereport(DEBUG3, (errmsg("In jq_nfields")));
	return 0;
}

int
jq_get_is_null(const Jresult * res, int tup_num, int field_num)
{
	ereport(DEBUG3, (errmsg("In jq_get_is_null")));
	return 0;
}

Jconn *
jq_connect_db_params(const ForeignServer * server, const UserMapping * user,
					 const char *const *keywords, const char *const *values)
{
	Jconn	   *conn;
	int			i = 0;

	ereport(DEBUG3, (errmsg("In jq_connect_db_params")));
	while (keywords[i])
	{
		const char *pvalue = values[i];

		if (pvalue == NULL && pvalue[0] == '\0')
		{
			break;
		}
		i++;
	}
	/* Initialize the Java JVM (if it has not been done already) */
	jdbc_jvm_init(server, user);
	conn = jdbc_create_JDBC_connection(server, user);
	if (jq_status(conn) == CONNECTION_BAD)
	{
		(void) jdbc_connect_db_complete(conn);
	}
	return conn;
}

/*
 * Do any cleanup needed and close a database connection Return 1 on success,
 * 0 on failure
 */
static int
jdbc_connect_db_complete(Jconn * conn)
{
	ereport(DEBUG3, (errmsg("In jdbc_connect_db_complete")));
	return 0;
}

ConnStatusType
jq_status(const Jconn * conn)
{
	if (!conn)
	{
		return CONNECTION_BAD;
	}
	return conn->status;
}

char *
jq_error_message(const Jconn * conn)
{
	ereport(DEBUG3, (errmsg("In jq_error_message")));
	return "Unknown Error!";
}

int
jq_connection_used_password(const Jconn * conn)
{
	ereport(DEBUG3, (errmsg("In jq_connection_used_password")));
	return 0;
}

void
jq_finish(Jconn * conn)
{
	ereport(DEBUG3, (errmsg("In jq_finish for conn=%p", conn)));
	jdbc_detach_jvm();
	conn = NULL;
	return;
}

int
jq_server_version(const Jconn * conn)
{
	ereport(DEBUG3, (errmsg("In jq_server_version")));
	return 0;
}

char *
jq_result_error_field(const Jresult * res, int fieldcode)
{
	ereport(DEBUG3, (errmsg("In jq_result_error_field")));
	return 0;
}

PGTransactionStatusType
jq_transaction_status(const Jconn * conn)
{
	ereport(DEBUG3, (errmsg("In jq_transaction_status")));
	return PQTRANS_UNKNOWN;
}
void *
jq_bind_sql_var(Jconn * conn, Oid type, int attnum, Datum value, bool *isnull, int resultSetID)
{
	jmethodID	idBindPreparedStatement;
	jclass		JDBCUtilsClass;
	jobject		JDBCUtilsObject;
	Jresult	   *res;

	ereport(DEBUG3, (errmsg("In jq_bind_sql_var")));

	res = (Jresult *) palloc0(sizeof(Jresult));
	*res = PGRES_FATAL_ERROR;

	jq_get_JDBCUtils(conn, &JDBCUtilsClass, &JDBCUtilsObject);

	attnum++;
	elog(DEBUG2, "jdbc_fdw : %s %d type=%u ", __func__, attnum, type);

	if (*isnull)
	{
		idBindPreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "bindNullPreparedStatement",
													   "(II)V");
		if (idBindPreparedStatement == NULL)
		{
			ereport(ERROR, (errmsg("Failed to find the JDBCUtils.bind method!")));
		}
		jq_exception_clear();
		(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idBindPreparedStatement, attnum, resultSetID);
		jq_get_exception();
		*res = PGRES_COMMAND_OK;
		return NULL;
	}

	switch (type)
	{
		case INT2OID:
			{
				int16		dat = DatumGetInt16(value);

				idBindPreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "bindIntPreparedStatement",
															   "(III)V");
				if (idBindPreparedStatement == NULL)
				{
					ereport(ERROR, (errmsg("Failed to find the JDBCUtils.bindInt method!")));
				}
				jq_exception_clear();
				(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idBindPreparedStatement, dat, attnum, resultSetID);
				jq_get_exception();
				break;
			}
		case INT4OID:
			{
				int32		dat = DatumGetInt32(value);

				idBindPreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "bindIntPreparedStatement",
															   "(III)V");
				if (idBindPreparedStatement == NULL)
				{
					ereport(ERROR, (errmsg("Failed to find the JDBCUtils.bindInt method!")));
				}
				jq_exception_clear();
				(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idBindPreparedStatement, dat, attnum, resultSetID);
				jq_get_exception();
				break;
			}
		case INT8OID:
			{
				int64		dat = DatumGetInt64(value);

				idBindPreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "bindLongPreparedStatement",
															   "(JII)V");
				if (idBindPreparedStatement == NULL)
				{
					ereport(ERROR, (errmsg("Failed to find the JDBCUtils.bindLong method!")));
				}
				jq_exception_clear();
				(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idBindPreparedStatement, dat, attnum, resultSetID);
				jq_get_exception();
				break;
			}

		case FLOAT4OID:

			{
				float4		dat = DatumGetFloat4(value);

				idBindPreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "bindFloatPreparedStatement",
															   "(FII)V");
				if (idBindPreparedStatement == NULL)
				{
					ereport(ERROR, (errmsg("Failed to find the JDBCUtils.bindFloat method!")));
				}
				jq_exception_clear();
				(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idBindPreparedStatement, dat, attnum, resultSetID);
				jq_get_exception();
				break;
			}
		case FLOAT8OID:
			{
				float8		dat = DatumGetFloat8(value);

				idBindPreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "bindDoublePreparedStatement",
															   "(DII)V");
				if (idBindPreparedStatement == NULL)
				{
					ereport(ERROR, (errmsg("Failed to find the JDBCUtils.bindDouble method!")));
				}
				jq_exception_clear();
				(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idBindPreparedStatement, dat, attnum, resultSetID);
				jq_get_exception();
				break;
			}

		case NUMERICOID:
			{
				Datum		valueDatum = DirectFunctionCall1(numeric_float8, value);
				float8		dat = DatumGetFloat8(valueDatum);

				idBindPreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "bindDoublePreparedStatement",
															   "(DII)V");
				if (idBindPreparedStatement == NULL)
				{
					ereport(ERROR, (errmsg("Failed to find the JDBCUtils.bindDouble method!")));
				}
				jq_exception_clear();
				(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idBindPreparedStatement, dat, attnum, resultSetID);
				jq_get_exception();
				break;
			}
		case BOOLOID:
			{
				bool		dat = (bool) value;

				idBindPreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "bindBooleanPreparedStatement",
															   "(ZII)V");
				if (idBindPreparedStatement == NULL)
				{
					ereport(ERROR, (errmsg("Failed to find the JDBCUtils.bindBoolean method!")));
				}
				jq_exception_clear();
				(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idBindPreparedStatement, dat, attnum, resultSetID);
				jq_get_exception();
				break;
			}

		case BYTEAOID:
			{
				long		len;
				char	   *dat = NULL;
				char	   *result = DatumGetPointer(value);
				jbyteArray	retArray;

				if (VARATT_IS_1B(result))
				{
					len = VARSIZE_1B(result) - VARHDRSZ_SHORT;
					dat = VARDATA_1B(result);
				}
				else
				{
					len = VARSIZE_4B(result) - VARHDRSZ;
					dat = VARDATA_4B(result);
				}

				retArray = (*Jenv)->NewByteArray(Jenv, len);
				(*Jenv)->SetByteArrayRegion(Jenv, retArray, 0, len, (jbyte *) (dat));


				idBindPreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "bindByteaPreparedStatement",
															   "([BJII)V");
				if (idBindPreparedStatement == NULL)
				{
					ereport(ERROR, (errmsg("Failed to find the JDBCUtils.bindBytea method!")));
				}
				jq_exception_clear();
				(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idBindPreparedStatement, retArray, len, attnum, resultSetID);
				jq_get_exception();
				break;
			}
		case BPCHAROID:
		case VARCHAROID:
		case TEXTOID:
		case JSONOID:
		case NAMEOID:
			{
				/* Bind as text */
				char	   *outputString = NULL;
				jstring		dat = NULL;
				Oid			outputFunctionId = InvalidOid;
				bool		typeVarLength = false;

				getTypeOutputInfo(type, &outputFunctionId, &typeVarLength);
				outputString = OidOutputFunctionCall(outputFunctionId, value);
				dat = (*Jenv)->NewStringUTF(Jenv, outputString);
				idBindPreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "bindStringPreparedStatement",
															   "(Ljava/lang/String;II)V");
				if (idBindPreparedStatement == NULL)
				{
					/* Return Java memory */
					(*Jenv)->DeleteLocalRef(Jenv, dat);
					ereport(ERROR, (errmsg("Failed to find the JDBCUtils.bindString method!")));
				}
				jq_exception_clear();
				(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idBindPreparedStatement, dat, attnum, resultSetID);
				jq_get_exception();

				/* Return Java memory */
				(*Jenv)->DeleteLocalRef(Jenv, dat);
				break;
			}
		case TIMEOID:
			{
				/* Bind as text */
				char	   *outputString = NULL;
				jstring		dat = NULL;
				Oid			outputFunctionId = InvalidOid;
				bool		typeVarLength = false;

				getTypeOutputInfo(type, &outputFunctionId, &typeVarLength);
				outputString = OidOutputFunctionCall(outputFunctionId, value);
				dat = (*Jenv)->NewStringUTF(Jenv, outputString);
				idBindPreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "bindTimePreparedStatement",
															   "(Ljava/lang/String;II)V");
				if (idBindPreparedStatement == NULL)
				{
					/* Return Java memory */
					(*Jenv)->DeleteLocalRef(Jenv, dat);
					ereport(ERROR, (errmsg("Failed to find the JDBCUtils.bindTime method!")));
				}
				jq_exception_clear();
				(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idBindPreparedStatement, dat, attnum, resultSetID);
				jq_get_exception();

				/* Return Java memory */
				(*Jenv)->DeleteLocalRef(Jenv, dat);
				break;
			}
		case TIMETZOID:
			{
				/* Bind as text */
				char	   *outputString = NULL;
				jstring		dat = NULL;
				Oid			outputFunctionId = InvalidOid;
				bool		typeVarLength = false;

				getTypeOutputInfo(type, &outputFunctionId, &typeVarLength);
				outputString = OidOutputFunctionCall(outputFunctionId, value);
				dat = (*Jenv)->NewStringUTF(Jenv, outputString);
				idBindPreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "bindTimeTZPreparedStatement",
															   "(Ljava/lang/String;II)V");
				if (idBindPreparedStatement == NULL)
				{
					/* Return Java memory */
					(*Jenv)->DeleteLocalRef(Jenv, dat);
					ereport(ERROR, (errmsg("Failed to find the JDBCUtils.bindTimeTZ method!")));
				}
				jq_exception_clear();
				(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idBindPreparedStatement, dat, attnum, resultSetID);
				jq_get_exception();

				/* Return Java memory */
				(*Jenv)->DeleteLocalRef(Jenv, dat);
				break;
			}
		case TIMESTAMPOID:
		case TIMESTAMPTZOID:
			{
				/*
				 * Bind as microseconds from Unix Epoch time in UTC time zone
				 * to avoid being affected by JVM's time zone.
				 */
				Timestamp	valueTimestamp = DatumGetTimestamp(value);		/* Already in UTC time zone */
				int64		valueMicroSecs = valueTimestamp + POSTGRES_TO_UNIX_EPOCH_USECS;

				idBindPreparedStatement = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "bindTimestampPreparedStatement",
															   "(JII)V");
				if (idBindPreparedStatement == NULL)
				{
					ereport(ERROR, (errmsg("Failed to find the JDBCUtils.bindTimestamp method!")));
				}
				jq_exception_clear();
				(*Jenv)->CallObjectMethod(Jenv, conn->JDBCUtilsObject, idBindPreparedStatement, valueMicroSecs, attnum, resultSetID);
				jq_get_exception();
				break;
			}
		default:
			{
				ereport(ERROR, (errcode(ERRCODE_FDW_INVALID_DATA_TYPE),
								errmsg("cannot convert constant value to JDBC value %u", type),
								errhint("Constant value data type: %u", type)));
				break;
			}
	}
	*res = PGRES_COMMAND_OK;
	return 0;
}

/*
 * jdbc_convert_to_pg: Convert JDBC data into PostgreSQL's compatible data
 * types
 */
Datum
jdbc_convert_to_pg(Oid pgtyp, int pgtypmod, char *value)
{
	Datum		valueDatum;
	Datum		stringDatum;
	regproc		typeinput;
	HeapTuple	tuple;
	int			typemod;

	/* get the type's output function */
	tuple = SearchSysCache1(TYPEOID, ObjectIdGetDatum(pgtyp));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for type%u", pgtyp);

	typeinput = ((Form_pg_type) GETSTRUCT(tuple))->typinput;
	typemod = ((Form_pg_type) GETSTRUCT(tuple))->typtypmod;
	ReleaseSysCache(tuple);

	stringDatum = CStringGetDatum(value);
	valueDatum = OidFunctionCall3(typeinput, stringDatum,
								   ObjectIdGetDatum(pgtyp),
								   Int32GetDatum(typemod));

	return valueDatum;
}

/*
 * jq_exception_clear: clears any exception that is currently being thrown
 */
void
jq_exception_clear()
{
	(*Jenv)->ExceptionClear(Jenv);
	return;
}

/*
 * jq_get_exception: get the JNI exception is currently being thrown convert
 * to String for ouputing error message
 */
void
jq_get_exception()
{
	/* check for pending exceptions */
	if ((*Jenv)->ExceptionCheck(Jenv))
	{
		jthrowable	exc;
		jmethodID	exceptionMsgID;
		jclass		objectClass;
		jstring		exceptionMsg;
		char	   *exceptionString;
		char	   *err_msg = NULL;

		/* determines if an exception is being thrown */
		exc = (*Jenv)->ExceptionOccurred(Jenv);
		/* get to the message and stack trace one as String */
		objectClass = (*Jenv)->FindClass(Jenv, "java/lang/Object");
		if (objectClass == NULL)
		{
			ereport(ERROR, (errmsg("java/lang/Object class could not be created")));
		}
		exceptionMsgID = (*Jenv)->GetMethodID(Jenv, objectClass, "toString", "()Ljava/lang/String;");
		exceptionMsg = (jstring) (*Jenv)->CallObjectMethod(Jenv, exc, exceptionMsgID);
		exceptionString = jdbc_convert_string_to_cstring((jobject) exceptionMsg);
		err_msg = pstrdup(exceptionString);
		ereport(ERROR, (errmsg("remote server returned an error")));
		ereport(DEBUG3, (errmsg("%s", err_msg)));
	}
	return;
}

static List *
jq_get_column_infos(Jconn * conn, char *tablename)
{
	jobject		JDBCUtilsObject;
	jclass		JDBCUtilsClass;
	jstring		jtablename = (*Jenv)->NewStringUTF(Jenv, tablename);
	int			i;

	/* getColumnNames */
	jmethodID	idGetColumnNames;
	jobjectArray columnNamesArray;
	jsize		numberOfNames;

	/* getColumnTypes */
	jmethodID	idGetColumnTypes;
	jobjectArray columnTypesArray;
	jsize		numberOfTypes;

	/* getPrimaryKey */
	jmethodID	idGetPrimaryKey;
	jobjectArray primaryKeyArray;
	jsize		numberOfKeys;
	List	   *primaryKey = NIL;

	/* for generating columnInfo List */
	List	   *columnInfoList = NIL;
	JcolumnInfo *columnInfo;
	ListCell   *lc;

	/* Get JDBCUtils */
	PG_TRY();
	{
		jq_get_JDBCUtils(conn, &JDBCUtilsClass, &JDBCUtilsObject);
	}
	PG_CATCH();
	{
		(*Jenv)->DeleteLocalRef(Jenv, jtablename);
		PG_RE_THROW();
	}
	PG_END_TRY();

	jdbc_sig_int_interrupt_check_process();
	/* getColumnNames */
	idGetColumnNames = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "getColumnNames", "(Ljava/lang/String;)[Ljava/lang/String;");
	if (idGetColumnNames == NULL)
	{
		(*Jenv)->DeleteLocalRef(Jenv, jtablename);
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.getColumnNames method")));
	}
	jq_exception_clear();
	columnNamesArray = (*Jenv)->CallObjectMethod(Jenv, JDBCUtilsObject, idGetColumnNames, jtablename);
	jq_get_exception();
	/* getColumnTypes */
	idGetColumnTypes = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "getColumnTypes", "(Ljava/lang/String;)[Ljava/lang/String;");
	if (idGetColumnTypes == NULL)
	{
		(*Jenv)->DeleteLocalRef(Jenv, jtablename);
		if (columnNamesArray != NULL)
		{
			(*Jenv)->DeleteLocalRef(Jenv, columnNamesArray);
		}
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.getColumnTypes method")));
	}
	jq_exception_clear();
	columnTypesArray = (*Jenv)->CallObjectMethod(Jenv, JDBCUtilsObject, idGetColumnTypes, jtablename);
	jq_get_exception();
	/* getPrimaryKey */
	idGetPrimaryKey = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "getPrimaryKey", "(Ljava/lang/String;)[Ljava/lang/String;");
	if (idGetPrimaryKey == NULL)
	{
		(*Jenv)->DeleteLocalRef(Jenv, jtablename);
		if (columnNamesArray != NULL)
		{
			(*Jenv)->DeleteLocalRef(Jenv, columnNamesArray);
		}
		if (columnTypesArray != NULL)
		{
			(*Jenv)->DeleteLocalRef(Jenv, columnTypesArray);
		}
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.getColumnTypes method")));
	}
	jq_exception_clear();
	primaryKeyArray = (*Jenv)->CallObjectMethod(Jenv, JDBCUtilsObject, idGetPrimaryKey, jtablename);
	jq_get_exception();
	if (primaryKeyArray != NULL)
	{
		numberOfKeys = (*Jenv)->GetArrayLength(Jenv, primaryKeyArray);
		for (i = 0; i < numberOfKeys; i++)
		{
			char	   *tmpPrimaryKey = jdbc_convert_string_to_cstring((jobject) (*Jenv)->GetObjectArrayElement(Jenv, primaryKeyArray, i));

			primaryKey = lappend(primaryKey, tmpPrimaryKey);
		}
		(*Jenv)->DeleteLocalRef(Jenv, primaryKeyArray);
	}

	if (columnNamesArray != NULL && columnTypesArray != NULL)
	{
		numberOfNames = (*Jenv)->GetArrayLength(Jenv, columnNamesArray);
		numberOfTypes = (*Jenv)->GetArrayLength(Jenv, columnTypesArray);

		if (numberOfNames != numberOfTypes)
		{
			(*Jenv)->DeleteLocalRef(Jenv, jtablename);
			(*Jenv)->DeleteLocalRef(Jenv, columnTypesArray);
			(*Jenv)->DeleteLocalRef(Jenv, columnNamesArray);
			ereport(ERROR, (errmsg("Cannot get the dependable columnInfo.")));
		}

		for (i = 0; i < numberOfNames; i++)
		{
			/* init columnInfo */
			char	   *tmpColumnNames = jdbc_convert_string_to_cstring((jobject) (*Jenv)->GetObjectArrayElement(Jenv, columnNamesArray, i));
			char	   *tmpColumnTypes = jdbc_convert_string_to_cstring((jobject) (*Jenv)->GetObjectArrayElement(Jenv, columnTypesArray, i));

			columnInfo = (JcolumnInfo *) palloc0(sizeof(JcolumnInfo));
			columnInfo->column_name = tmpColumnNames;
			columnInfo->column_type = tmpColumnTypes;
			columnInfo->primary_key = false;
			/* check the column is primary key or not */
			foreach(lc, primaryKey)
			{
				char	   *tmpPrimaryKey = NULL;

				tmpPrimaryKey = (char *) lfirst(lc);
				if (!strcmp(tmpPrimaryKey, tmpColumnNames))
				{
					columnInfo->primary_key = true;
				}
			}
			columnInfoList = lappend(columnInfoList, columnInfo);
		}
	}

	if (columnNamesArray != NULL)
	{
		(*Jenv)->DeleteLocalRef(Jenv, columnNamesArray);
	}
	if (columnTypesArray != NULL)
	{
		(*Jenv)->DeleteLocalRef(Jenv, columnTypesArray);
	}
	(*Jenv)->DeleteLocalRef(Jenv, jtablename);

	return columnInfoList;
}

/*
 * jq_get_column_infos_without_key
 *
 * This function is clone from jq_get_column_infos
 * to get column names and data types.
 * Primary key is set to false because it is not necessary.
 *
 */
List *
jq_get_column_infos_without_key(Jconn * conn, int *resultSetID, int *column_num)
{
	jobject		JDBCUtilsObject;
	jclass		JDBCUtilsClass;
	int			i;

	/* getColumnNames */
	jmethodID	idGetColumnNamesByResultSetID;
	jobjectArray columnNamesArray;
	jsize		numberOfNames;

	/* getColumnTypes */
	jmethodID	idGetColumnTypesByResultSetID;
	jobjectArray columnTypesArray;
	jsize		numberOfTypes;

	/* getColumnNumber */
	jmethodID	idNumberOfColumns;
	jint		jresultSetID = *resultSetID;
	int			numberOfColumns;

	/* for generating columnInfo List */
	List	   *columnInfoList = NIL;
	JcolumnInfo *columnInfo;

	/* Get JDBCUtils */
	PG_TRY();
	{
		jq_get_JDBCUtils(conn, &JDBCUtilsClass, &JDBCUtilsObject);
	}
	PG_CATCH();
	{
		PG_RE_THROW();
	}
	PG_END_TRY();

	jdbc_sig_int_interrupt_check_process();

	/* getColumnNames by resultSetID */
	idGetColumnNamesByResultSetID = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "getColumnNamesByResultSetID", "(I)[Ljava/lang/String;");
	if (idGetColumnNamesByResultSetID == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.getColumnNamesByResultSetID method")));
	}
	jq_exception_clear();
	columnNamesArray = (*Jenv)->CallObjectMethod(Jenv, JDBCUtilsObject, idGetColumnNamesByResultSetID, jresultSetID);
	jq_get_exception();

	/* getColumnTypes by resultSetID */
	idGetColumnTypesByResultSetID = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "getColumnTypesByResultSetID", "(I)[Ljava/lang/String;");
	if (idGetColumnTypesByResultSetID == NULL)
	{
		if (columnNamesArray != NULL)
		{
			(*Jenv)->DeleteLocalRef(Jenv, columnNamesArray);
		}
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.getColumnTypesByResultSetID method")));
	}
	jq_exception_clear();
	columnTypesArray = (*Jenv)->CallObjectMethod(Jenv, JDBCUtilsObject, idGetColumnTypesByResultSetID, jresultSetID);
	jq_get_exception();

	/* getNumberOfColumns */
	idNumberOfColumns = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "getNumberOfColumns", "(I)I");
	if (idNumberOfColumns == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.getNumberOfColumns method")));
	}
	jq_exception_clear();
	numberOfColumns = (int) (*Jenv)->CallIntMethod(Jenv, JDBCUtilsObject, idNumberOfColumns, jresultSetID);
	*column_num = numberOfColumns;
	jq_get_exception();

	if (columnNamesArray != NULL && columnTypesArray != NULL)
	{
		numberOfNames = (*Jenv)->GetArrayLength(Jenv, columnNamesArray);
		numberOfTypes = (*Jenv)->GetArrayLength(Jenv, columnTypesArray);

		if (numberOfNames != numberOfTypes)
		{
			(*Jenv)->DeleteLocalRef(Jenv, columnTypesArray);
			(*Jenv)->DeleteLocalRef(Jenv, columnNamesArray);
			ereport(ERROR, (errmsg("Cannot get the dependable columnInfo.")));
		}

		for (i = 0; i < numberOfNames; i++)
		{
			/* init columnInfo */
			char	   *tmpColumnNames = jdbc_convert_string_to_cstring((jobject) (*Jenv)->GetObjectArrayElement(Jenv, columnNamesArray, i));
			char	   *tmpColumnTypes = jdbc_convert_string_to_cstring((jobject) (*Jenv)->GetObjectArrayElement(Jenv, columnTypesArray, i));

			columnInfo = (JcolumnInfo *) palloc0(sizeof(JcolumnInfo));
			columnInfo->column_name = tmpColumnNames;
			columnInfo->column_type = tmpColumnTypes;
			columnInfo->primary_key = false;

			columnInfoList = lappend(columnInfoList, columnInfo);
		}
	}

	if (columnNamesArray != NULL)
	{
		(*Jenv)->DeleteLocalRef(Jenv, columnNamesArray);
	}
	if (columnTypesArray != NULL)
	{
		(*Jenv)->DeleteLocalRef(Jenv, columnTypesArray);
	}

	return columnInfoList;
}

/*
 * jq_get_table_names
 */
static List *
jq_get_table_names(Jconn * conn)
{
	jobject		JDBCUtilsObject;
	jclass		JDBCUtilsClass;
	jmethodID	idGetTableNames;
	jobjectArray tableNameArray;
	List	   *tableName = NIL;
	jsize		numberOfTables;
	int			i;

	jq_get_JDBCUtils(conn, &JDBCUtilsClass, &JDBCUtilsObject);

	jdbc_sig_int_interrupt_check_process();
	idGetTableNames = (*Jenv)->GetMethodID(Jenv, JDBCUtilsClass, "getTableNames", "()[Ljava/lang/String;");
	if (idGetTableNames == NULL)
	{
		ereport(ERROR, (errmsg("Failed to find the JDBCUtils.getTableNames method")));
	}
	jq_exception_clear();
	tableNameArray = (*Jenv)->CallObjectMethod(Jenv, JDBCUtilsObject, idGetTableNames);
	jq_get_exception();
	if (tableNameArray != NULL)
	{
		numberOfTables = (*Jenv)->GetArrayLength(Jenv, tableNameArray);
		for (i = 0; i < numberOfTables; i++)
		{
			char	   *tmpTableName = jdbc_convert_string_to_cstring((jobject) (*Jenv)->GetObjectArrayElement(Jenv, tableNameArray, i));

			tableName = lappend(tableName, tmpTableName);
		}
		(*Jenv)->DeleteLocalRef(Jenv, tableNameArray);
	}
	return tableName;
}

/*
 * jq_get_schema_info
 */
List *
jq_get_schema_info(Jconn * conn)
{
	List	   *schema_list = NIL;
	List	   *tableName = NIL;
	JtableInfo *tableInfo;
	ListCell   *lc;

	tableName = jq_get_table_names(conn);

	foreach(lc, tableName)
	{
		char	   *tmpTableName = NULL;

		tmpTableName = (char *) lfirst(lc);
		tableInfo = (JtableInfo *) palloc0(sizeof(JtableInfo));
		if (tmpTableName != NULL)
		{
			tableInfo->table_name = tmpTableName;
			tableInfo->column_info = jq_get_column_infos(conn, tmpTableName);
			schema_list = lappend(schema_list, tableInfo);
		}
	}
	return schema_list;
}

/*
 * jq_get_JDBCUtils: get JDBCUtilsClass and JDBCUtilsObject
 */
static void
jq_get_JDBCUtils(Jconn *conn, jclass *JDBCUtilsClass, jobject *JDBCUtilsObject)
{
	/* Our object of the JDBCUtils class is on the connection */
	*JDBCUtilsObject = conn->JDBCUtilsObject;
	if (*JDBCUtilsObject == NULL)
	{
		ereport(ERROR, (errmsg("Cannot get the utilsObject from the connection")));
	}
	*JDBCUtilsClass = (*Jenv)->FindClass(Jenv, "JDBCUtils");
	if (*JDBCUtilsClass == NULL)
	{
		ereport(ERROR, (errmsg("JDBCUtils class could not be created")));
	}
}
