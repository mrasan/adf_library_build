#!/bin/bash
function copy_with_structure(){
	DIR_LEN=${#1}
	SUB=${2:${DIR_LEN}}
	DEST=${3}/$SUB
	DEST_DIR=`dirname $DEST`
	if [ ! -d $DEST_DIR ]; then
		mkdir -p $DEST_DIR
	fi
	cp $2 $DEST
}
strindex() { 
  x="${1%%$2*}"
  [[ "$x" = "$1" ]] && echo -1 || echo "${#x}"
}
get_taskflow_parameters(){
	TEXT=$(<$1)
	s1="input-parameter-definition"
	s2="</input-parameter-definition>"
	while :
	do
		start=`strindex "$TEXT" "$s1"`
		if [ "$start" = "-1" ]; then
			break
		fi
		end=`strindex "$TEXT" $s2`
		sub="${TEXT:$start:$end-$start}"
		if [ ! "$parameter" = "" ]; then
			parameter="${parameter} "
		fi
		p=`echo "$sub"|grep "name"|cut -d ">" -f 2|cut -d "<" -f 1`
		parameter="${parameter}${p}"
		TEXT="${TEXT:$end+${#s2}}"
	done
	echo $parameter
}
ADF_WORKSPACE=$1
ADF_MODULES=$2
ADF_DEPLOY=$ADF_WORKSPACE/deploy
FLAG=1
#init
rm -rf ${ADF_DEPLOY}
mkdir -p ${ADF_DEPLOY}
mkdir -p ${ADF_DEPLOY}/META-INF
mkdir -p ${ADF_DEPLOY}/WEB-INF

#test
ADF_VIEW=${ADF_WORKSPACE}/ViewController


for jar in $ADF_MODULES/*
do
	if [ $FLAG = 0 ]; then
		CLASS_PATH="${CLASS_PATH}:"
	fi
	FLAG=0
	CLASS_PATH="${CLASS_PATH}$jar"
done
#compile model java source files
ADF_MODEL=${ADF_WORKSPACE}/Model
for x in `find ${ADF_MODEL}/src -name "*.java"`
do
	SOURCE_FILE="${SOURCE_FILE}${x} "
done
javac -classpath ${CLASS_PATH} -d $ADF_DEPLOY ${SOURCE_FILE}

#compile view java source files
ADF_VIEW=${ADF_WORKSPACE}/ViewController
SOURCE_FILE=""
for x in `find ${ADF_VIEW}/src -name "*.java"`
do
	SOURCE_FILE="${SOURCE_FILE}${x} "
done
javac -classpath ${CLASS_PATH} -d $ADF_DEPLOY ${SOURCE_FILE}

#copy files
cp $ADF_VIEW/public_html/WEB-INF/adfc-config.xml $ADF_DEPLOY/META-INF/
cp $ADF_VIEW/public_html/WEB-INF/faces-config.xml $ADF_DEPLOY/META-INF/
cp $ADF_VIEW/adfmsrc/META-INF/adfm.xml $ADF_DEPLOY/META-INF/
cp -R $ADF_VIEW/public_html/WEB-INF/ $ADF_DEPLOY/WEB-INF

#copy taskflows
TASKFLOW_REGISTRY=$ADF_DEPLOY/META-INF/task-flow-registry.xml
echo -e "<?xml version = '1.0' encoding = 'UTF-8'?>\n" >>$TASKFLOW_REGISTRY
echo -e "<task-flow-registry xmlns=\"http://xmlns.oracle.com/adf/controller/rc\">\n" >>$TASKFLOW_REGISTRY
for x in `find $ADF_DEPLOY/WEB-INF -name "*.xml"`
do
	grep "task-flow-definition" $x >/dev/null
	if [ $? -ne 0 ]; then
		rm -rf $x
	else
		#write taskflow-registy
		TASKFLOW_NAME=`basename ${x} .xml`
		PARAMETERS=`get_taskflow_parameters ${x}`
		INDEX=`strindex "$x" "WEB-INF"`
		echo -e "<task-flow-descriptor path=\"${x:${INDEX}}\" id=\"${TASKFLOW_NAME}\" type=\"task-flow-definition\" uses-page-fragments=\"true\" library-internal=\"false\" train=\"false\">\n" >>$TASKFLOW_REGISTRY
		for y in $PARAMETERS
		do
			if [ ! "${y}" = "" ]; then
				echo -e "<input-parameter name=\"${y}\"/>\n" >>$TASKFLOW_REGISTRY
			fi
		done
		echo -e "</task-flow-descriptor>\n" >>$TASKFLOW_REGISTRY
	fi
done∂
echo "</task-flow-registry>" >>$TASKFLOW_REGISTRY

if [ -f "$ADF_VIEW/public_html/WEB-INF/weblogic.xml" ]; then
	cp $ADF_VIEW/public_html/WEB-INF/weblogic.xml $ADF_DEPLOY/WEB-INF/
fi
#copy defination
for x in `find $ADF_VIEW/adfmsrc ! -wholename "*META-INF*" -type f`
do
	copy_with_structure ${ADF_VIEW}/adfmsrc/ $x ${ADF_DEPLOY}
done
#copy jsffs...
for x in `find $ADF_VIEW/public_html ! -name "*.xml" -type f`
do
	copy_with_structure $ADF_VIEW/public_html $x ${ADF_DEPLOY}
done
#copy bc components
for x in `find $ADF_MODEL/src ! -name "*.java" -type f`
do
	copy_with_structure $ADF_MODEL/src $x ${ADF_DEPLOY}
done

#package to jar
cd ${ADF_WORKSPACE}/deploy
jar -cvf deploy.jar *

exit 0
