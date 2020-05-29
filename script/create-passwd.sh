#!/bin/bash
for i in {1..40}
do
A=`head -c 500 /dev/urandom | tr -dc A-Z |head -c 2`
#随机生成500字符|只取大写字母|取第一个字符
B=`head -c 500 /dev/urandom | tr -dc [:alnum:]| head -c 4`
#随机生成500字符|取英文大小写字节及数字，亦即 0-9, A-Z, a-z|取6位
C=`echo $RANDOM$RANDOM|cut -c 2`
D=`echo $RANDOM$RANDOM|cut -c 2`
#取第二位随机数字,第一位随机性不高大多数是1或2,所以取第二位.
echo $A$C$B$C$D
done

