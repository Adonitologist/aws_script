#!/bin/bash
echo "--- Iniciando configuracion en Cloud9 ---"

# Instalacion de Maven [cite: 9, 10, 11]
sudo apt update -y && sudo apt install maven -y
mvn -version

# Crear proyecto Maven [cite: 12, 13]
mvn archetype:generate -DgroupId=com.ejemplo -DartifactId=MiProyecto -DarchetypeArtifactId=maven-archetype-quickstart -DinteractiveMode=false

cd MiProyecto

# Configurar pom.xml con Driver MySQL [cite: 31, 32]
cat <<EOF > pom.xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.ejemplo</groupId>
  <artifactId>MiProyecto</artifactId>
  <version>1.0-SNAPSHOT</version>
  <dependencies>
    <dependency>
      <groupId>mysql</groupId>
      <artifactId>mysql-connector-java</artifactId>
      <version>8.0.33</version>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.codehaus.mojo</groupId>
        <artifactId>exec-maven-plugin</artifactId>
        <version>3.1.0</version>
        <configuration>
          <mainClass>com.ejemplo.App</mainClass>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
EOF

# Crear App.java para estres de conexiones [cite: 5, 37]
mkdir -p src/main/java/com/ejemplo/
cat <<EOF > src/main/java/com/ejemplo/App.java
package com.ejemplo;
import java.sql.Connection;
import java.sql.DriverManager;
import java.util.ArrayList;
import java.util.List;

public class App {
    public static void main(String[] args) {
        String url = "jdbc:mysql://TU_ENDPOINT_RDS:3306/ciclismo"; 
        String user = "admin";
        String password = "Password123!";
        List<Connection> connections = new ArrayList<>();

        try {
            System.out.println("Iniciando creacion de conexiones...");
            for (int i = 1; i <= 60; i++) { [cite: 5]
                connections.add(DriverManager.getConnection(url, user, password));
                System.out.println("Conexion #" + i + " establecida.");
            }
            System.out.println("60 conexiones abiertas. Revisa CloudWatch."); [cite: 41, 42]
            Thread.sleep(300000); 
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
EOF

echo "--- CONFIGURACION COMPLETADA ---"
echo "1. Edita MiProyecto/src/main/java/com/ejemplo/App.java con tu endpoint."
echo "2. Ejecuta: mvn compile && mvn exec:java" [cite: 47, 48]
