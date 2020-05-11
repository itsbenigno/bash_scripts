#!/bin/bash

# [e,r,t,f]given=0 -> the option was not given
egiven=0  
rgiven=0 
tgiven=0 
fgiven=0
xmode=0
smode=1 #safe mode (default)

eregex="" # pattern given to -e 

lstind=0 # the index of the first given argument 

######################################
# 1) Taking options and arguments

# display script's synopsis #
usage () {
echo -e "nametime [options] [file,dir] \n 
This script rename files with their creation timestamp \n
-e 'pattern' -> search only the files that have a match with 'pattern' \n 
-r -> search recursively into directories \n 
-t -> creates a file (oldnames.txt) with the old name \n
-f -> format all the file in standard unix but does not rename with the timestamp \n
-o '[x,s]' -> the default mode is -o 's', if a directory has not the right permission it ask the \n
	user the permission to change the permission, with the option 'x' it just change the permission \n
-h -> help menu \n " 

exit 1
}

OPTERR=0 # getops is silenced
while getopts ":e:rthfo:" opt; do 

	lstind=${OPTIND} 

	case ${opt} in

    e)
		eregex=${OPTARG} 
		egiven=1 
      ;;

    r)
		rgiven=1 
	  ;;

	f) 
		fgiven=1
		;;

	t) 
		tgiven=1
		;;

	o) 
		if [[ ${OPTARG} == "x" ]]
			then xmode=1
				smode=0

		elif [[ ${OPTARG} != "s" ]]
			then 
				echo "You can pass s or x to -o"
				usage
		fi
		;;

	h)
		usage  
		;;

	:) 
      	echo "You must give and argument to ${opt}"
     	usage
      ;;

    \?) #opzione sbagliata
      	echo "${opt} does not exist" 
      	usage
      ;;

  esac
done

# 1) end

##########################################
# 2) check if at least one argument was passed

if (( ${lstind} == 0)) && (( $# <1 )) 
	then 
		echo "You must give at least a directory or file path"
	  	usage
	fi

if  (( $# - ${lstind} +1 < 1 )) 
	then
	  	echo "You must give at least a directory or file path"
	  	usage 
	fi	

# 2) end 


# 3) storing and checking argument
	
if [[ ${lstind} -eq 0 ]] #if no option was given
then lstind=1			 
fi

#save tbe old name in a file before renaming
if [[ tgiven -eq 1 ]] 
	then 
		touch oldnames.txt
		echo oldname "--->" newname >> oldnames.txt
	fi

#### checks directory permission #######
#### in: dirname #######
checkdir(){
	checked=1
	local dirname="$1" 

	if [[ ! -w "$dirname" ]] || [[ ! -x "$dirname" ]] 
		then
			if [[ $smode -eq 1 ]] #safe mode
			then 
			echo "The file ${1} has not the right permession, you want to change that or exit? "
			read in
			if [[ "$in" == "yes" || "$in" == "y" ]]
				then chmod u+wx "$dirname" 
			elif [[ "$in" == "no" || "$in" == * ]] #in the final version it just ignore the file
				then checked=0
			fi
			elif [[ $xmode -eq 1 ]]
			then  chmod u+wx "$dirname"
			fi
	fi

}

##################################################
format(){

	local arg=$1
    local namearg="`basename "$arg"`"
    local tmpname=`echo "${namearg//[ ()@$]/_}"` #format unix style 
    local tmparg="`dirname "$arg"`/"$tmpname"" #WHAT IF IS A DIR?
	if [[ "$tmpname" != "$namearg" ]]
	then
		mv  "$arg" "$tmparg"
		echo "$tmparg"
	elif [[ "$tmpname" == "$namearg" ]]
		then
			echo "$arg"
	fi


    }

ignored=0 
declare -a argtosearch 

for (( i=lstind ; i <= $# ; i++ )) 
	do

    arg="${!i}" #indirect expansion

	if [[ -f "${arg}" ]] 
		then

		    tmparg="`format "$arg"`"
			argtosearch+=("$tmparg") #add to search queue

	elif [[ ${rgiven} -eq 0 ]] && [[ -d "${arg}" ]] 
		then
			echo "${arg} is a directory, you must use -r"
			((ignored += 1)) 

	elif [[ ${rgiven} -eq 0 ]] && [[ ! -f "${arg}" ]] 
		then
		 echo "${arg} does not exist"
			((ignored += 1))

	elif [[ ${rgiven} -eq 1 ]] && [[ -d "${arg}" ]] 
    	then 
    		checkdir "${arg}" 
    		if [[ $checked -eq 1 ]]
    		then
				tmparg="`format "$arg"`"
				argtosearch+=("$tmparg") #add to search queue

			elif [[ $checked -eq 0 ]]
				then ((ignored += 1))
				
			fi

	elif [[ ${rgiven} -eq 1 ]] && [[ ! -f ${arg} ]] 
		then echo "${arg} does not exist" 
			((ignored += 1))
	fi
done

# 3) end

##### in : filename 
rename(){
	
	local name="$1"
	local dir=`dirname "$name"`


	if [[ tgiven -eq 1 ]]
	then echo "$name" "--->" "$dir"/"`date -r "$name" +%Y%m%d_%H%M%S`" >> oldnames.txt
	fi
	local extension=`echo ${name##*.}`

	if [[ $extension == $1 ]]
	then 
		mv "$name" "$dir"/"`date -r "$name" +%Y%m%d_%H%M%S`"

	elif [[ $extension != $1 ]]
		then 
		mv "$name" "$dir"/"`date -r "$name" +%Y%m%d_%H%M%S`.${name##*.}"
	fi

}

#### in: directory #############
ricdirsearch(){


	for file in "$1"/* #it considers also hidden files
	do                                       
		local name="`format "$file"`"

		local nfl=`basename ${name}`


		if [[ "$nfl" == "*" ]]
			then echo > /dev/null

		elif [[ ! -d "$name" ]] && [[ "$egiven" -eq 1 ]] && [[ "$nfl" =~ "$eregex" ]]
			then 
				if [[ $fgiven -eq 0 ]]
				then
				rename "$name"
				fi

		elif [[ ! -d ${name} ]] 
			then 
				if [[ $fgiven -eq 0 ]]
				then
				rename "$name"
				fi
		
		elif [[ -d ${name} ]] 
			then 
				checkdir "$name" 
				if [[ $checked -eq 1 ]]
    			then
					ricdirsearch "$name"
				elif [[ $checked -eq 0 ]]
				then ((ignored += 1))
				
				fi


    	fi
				

	done
}
####################################################################



for arg in "${argtosearch[@]}" 
do 	
	
	if [[ -f "$arg" && $egiven -eq 1 && "$arg" =~ "$eregex" ]]
		then
			if [[ "$fgiven" -eq 0 ]]
			then
			rename "$arg"
			fi

	elif [[ -f "$arg" ]] 
		then
			if [[ "$fgiven" -eq 0 ]]
			then
			rename "$arg"
			fi

	elif [[ -d "$arg" ]]  
		then 
		ricdirsearch "$arg" 
	fi

done


exit ${ignored}
