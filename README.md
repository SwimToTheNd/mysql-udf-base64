# mysql-udf-base64
利用mysql udf(User Define Function)功能，给mysql添加base64编码与解码函数。
使用sql语言实现和C语言实现。
可以自定义编码规则。

## 查看mysql扩展函数所需存放的动态库所在目录
```
show variables like '%PLUGIN%' ;
```
## 查看mysql的udf函数
```
select * from mysql.func;
```
## 创建udf函数，名称与C++源码中函数名称相同
```
CREATE FUNCTION `udfbase64decode` RETURNS STRING
SONAME 'libmysqludf-db-encrypt.dll';

CREATE FUNCTION `udfbase64encode` RETURNS STRING
SONAME 'libmysqludf-db-encrypt.dll';
```
