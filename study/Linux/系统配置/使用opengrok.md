# opengrok配置

## 下载基本软件

* Java from 11 to 22
* [ctags](https://github.com/universal-ctags) for analysis
* Tomcat
* [opengrok](https://github.com/oracle/opengrok/releases)

## 设置opengrok

```Shell
mkdir -p opengrok/{src,data,dist,etc,log}
tar -C opengrok/dist --strip-components=1 -xzf opengrok-X.Y.Z.tar.gz
cp opengrok/dist/doc/logging.properties opengrok/etc

```

```Shell
log file的内容:
handlers= java.util.logging.FileHandler, java.util.logging.ConsoleHandler

java.util.logging.FileHandler.pattern = /opengrok/log/opengrok%g.%u.log
java.util.logging.FileHandler.append = false
java.util.logging.FileHandler.limit = 0
java.util.logging.FileHandler.count = 30
java.util.logging.FileHandler.level = ALL
java.util.logging.FileHandler.formatter = org.opengrok.indexer.logger.formatter.SimpleFileLogFormatter

java.util.logging.ConsoleHandler.level = WARNING
java.util.logging.ConsoleHandler.formatter = org.opengrok.indexer.logger.formatter.SimpleFileLogFormatter

org.opengrok.level = FINE
```

## 构建源码索引

```Shell
# 创建tomcat网站
export Proj=t602aa
cp opengrok/dist/lib/source.war /home/cyx/work_open/bin/apache-tomcat-10.1.17/webapps/${Proj}.war
mkdir opengrok/data/${Proj}

opengrok 常用参数：
-P, --projects
        Generate a project for each top-level directory in source root.

-S, --search [path/to/repository|@file_with_paths]
        Search for source repositories under source root (-s,--source),
        and add them. Path (relative to the source root) is optional.
        File containing the paths can be specified via @path syntax.
        Option may be repeated.

-G, --assignTags
        Assign commit tags to all entries in history for all repositories.

--disableRepository 类型名称
禁用 OpenGrok 支持的版本库操作。另见
-h,--help repos。此选项可重复。
示例：--disableRepository git
将禁用 GitRepository
示例：--disableRepository MercurialRepository

-i, --ignore 模式
忽略匹配的文件（前缀为 'f:' 或无前缀）或目录（前缀为 'd:'）。
模式支持通配符（示例：-i '.so' -i d:'test'）。此选项可重复。

-H
    Enable history.

-Xms2g -Xmx2g 
通过调整 JVM 参数 -Xms（初始堆大小）和 -Xmx（最大堆大小）来增加可用内存。

-Xms512m -Xmx8g -DOPENGROK_THREADS=4 -XX:ActiveProcessorCount=4 

export OPENGROK_THREADS=4

java \
    -Djava.util.logging.config.file=opengrok/etc/logging.properties \
    -jar opengrok/dist/lib/opengrok.jar \
    -c /usr/local/bin/ctags \
    -s /home/cyx/work_fast/p528/ \
    -d opengrok/data/${Proj} -P \
    -W opengrok/etc/configuration_${Proj}.xml \
    -U http://localhost:8080/${Proj}

更新的命令，解决jvm outofmemory问题
java -Xms512m -Xmx8g -DOPENGROK_THREADS=8 -XX:ActiveProcessorCount=8  -Djava.util.logging.config.file=opengrok/etc/logging.properties -jar opengrok/dist/lib/opengrok.jar -c /usr/local/bin/ctags -s /home/cyx/work_fast/m2521/ -d opengrok/data/${Proj} -P -i d:'out*' -i d:'*release*' -W opengrok/etc/configuration_${Proj}.xml -U http://localhost:8080/${Proj}
```

最后需要修改 tomcat/webapps/${Proj}/WEB-INF/web.xml
下的<param-name>CONFIGURATION</param-name> 值为
opengrok/etc/configuration_\${Proj}.xml

