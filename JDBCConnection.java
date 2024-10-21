/*-------------------------------------------------------------------------
 *
 *                foreign-data wrapper for JDBC
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * This software is released under the PostgreSQL Licence
 *
 * IDENTIFICATION
 *                jdbc_fdw/JDBCConnection.java
 *
 *-------------------------------------------------------------------------
 */

import java.io.File;
import java.net.URL;
import java.sql.*;
import java.util.Properties;
import java.util.concurrent.ConcurrentHashMap;

public class JDBCConnection {
    private Connection conn = null;
    private boolean invalidate;
    private long server_hashvalue; // keep the uint32 val
    private long mapping_hashvalue; // keep the uint32 val

    private int queryTimeoutValue;
    private static JDBCDriverLoader jdbcDriverLoader;

    /* JDBC connection hash map */
    private static ConcurrentHashMap<Integer, JDBCConnection> ConnectionHash = new ConcurrentHashMap<Integer, JDBCConnection>();

    public JDBCConnection(Connection conn, boolean invalidate, long server_hashvalue, long mapping_hashvalue, int queryTimeoutValue) {
        this.conn = conn;
        this.invalidate = invalidate;
        this.server_hashvalue = server_hashvalue;
        this.mapping_hashvalue = mapping_hashvalue;
        this.queryTimeoutValue = queryTimeoutValue;
    }

    /* finalize all actived connection */
    public static void finalizeAllConns(long hashvalue) throws Exception {
        for (JDBCConnection Jconn : ConnectionHash.values()) {
            Jconn.invalidate = true;

            if (Jconn.conn != null) {
                Jconn.conn.close();
                Jconn.conn = null;
            }
        }
    }

    /* finalize connection have given server_hashvalue */
    public static void finalizeAllServerConns(long hashvalue) throws Exception {
        for (JDBCConnection Jconn : ConnectionHash.values()) {
            if (Jconn.server_hashvalue == hashvalue) {
                Jconn.invalidate = true;
                System.out.println("Finalizing " +  Jconn);

                if (Jconn.conn != null) {
                    Jconn.conn.close();
                    Jconn.conn = null;
                }
                break;
            }
        }
    }

    /* finalize connection have given mapping_hashvalue */
    public static void finalizeAllUserMapingConns(long hashvalue) throws Exception {
        for (JDBCConnection Jconn : ConnectionHash.values()) {
            if (Jconn.mapping_hashvalue == hashvalue) {
                Jconn.invalidate = true;
                System.out.println("Finalizing " +  Jconn);

                if (Jconn.conn != null) {
                    Jconn.conn.close();
                    Jconn.conn = null;
                }
                break;
            }
        }
    }

    /* get query timeout value */
    public int getQueryTimeout() {
        return queryTimeoutValue;
    }

    public Connection getConnection() {
        return this.conn;
    }

    /* get jdbc connection, create new one if not cached before */
    public static JDBCConnection getConnection(int key, long server_hashvalue, long mapping_hashvalue, String[] options) throws Exception {
        if (ConnectionHash.containsKey(key)) {
            JDBCConnection Jconn = ConnectionHash.get(key);

            if (Jconn.invalidate == false) {
                System.out.println("got connection " + Jconn.getConnection());
                return Jconn;
            }

        }

        return createConnection(key, server_hashvalue, mapping_hashvalue, options);
    }

    /* Make new connection */
    public static JDBCConnection createConnection(int key, long server_hashvalue, long mapping_hashvalue, String[] options) throws Exception {
        Properties jdbcProperties;
        Class<?> jdbcDriverClass = null;
        Driver jdbcDriver = null;
        String driverClassName = options[0];
        String url = options[1];
        String userName = options[2];
        String password = options[3];
        String qTimeoutValue = options[4];
        String fileName = options[5];

        try {
            File JarFile = new File(fileName);
            String jarfile_path = JarFile.toURI().toURL().toString();

            if (jdbcDriverLoader == null) {
                /* If jdbcDriverLoader is being created. */
                jdbcDriverLoader = new JDBCDriverLoader(new URL[] {JarFile.toURI().toURL()});
            } else if (jdbcDriverLoader.CheckIfClassIsLoaded(driverClassName) == null) {
                jdbcDriverLoader.addPath(jarfile_path);
            }

            /* Make connection */
            jdbcDriverClass = jdbcDriverLoader.loadClass(driverClassName);
            jdbcDriver = (Driver) jdbcDriverClass.newInstance();
            jdbcProperties = new Properties();
            if (null != userName && !userName.trim().equals("")) jdbcProperties.put("user", userName);
            if (null != password && !password.trim().equals("")) jdbcProperties.put("password", password);
            Connection conn = jdbcDriver.connect(url, jdbcProperties);

            if (conn == null)
                throw new SQLException("Cannot connect server: " + url);

            JDBCConnection Jconn = new JDBCConnection(conn, false, server_hashvalue, mapping_hashvalue, Integer.parseInt(qTimeoutValue));

            /* cache new connection */
            System.out.println("Create new connection " + key);
            ConnectionHash.put(key, Jconn);

            return Jconn;
        } catch (Throwable e) {
            throw e;
        }
    }
}
