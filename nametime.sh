#!/bin/bash


epresente=0 # 0 -> l'opzione e non è presente
rpresente=0 # 0 -> l'opzione r non è presente
tpresente=0 

eregex="" #argomento di -e 

lstind=0 #indice dell'inizio degli argomenti

######################################


# 1) prendo le opzioni e i loro argomenti

OPTERR=0 #non mostra errori di getops
while getopts ":e:rth" opt; do # serve il : all'inizio per far funzionare : (entra in modalità non verb.)

	lstind=${OPTIND} #viene aumentato da getops scorrendo le opzioni

	case ${opt} in

    e)
		eregex=${OPTARG} #salvo la regex
		epresente=1 
      ;;

    r)
		rpresente=1 
	  ;;

	 t) 
		tpresente=1
		;;
	h)
		echo "nametime.sh [-e rgx] -[rt] argtorename" 
		;;
	:) # non ho passato l'argomento ad e
      	echo "Devi passare il pattern che vuoi cercare"
     	 exit 1
      ;;

    \?) #opzione sbagliata
      	echo "hai dato un'opzione che non esiste" 
      	exit 2
      ;;

  esac
done

# 1) fine 


# 2) non è stato passato almeno un argomento

if (( ${lstind} == 0)) && (( $# <1 )) #non hai dato un argomento (nel caso senza opzioni)
	then 
		echo "Devi passare almeno un argomento da rinominare"
	  	exit 3
	fi

if  (( $# - ${lstind} +1 < 1 )) #non hai dato nemmeno un argomento (nel caso in cui abbia dato opzioni)
	then
	  	echo "Devi passare almeno un argomento da rinominare"
	  	exit 3
	fi	

# 2) fine 


# 3) inserimento argomenti in un array e controllo sui file in input
	
if [[ ${lstind} -eq 0 ]] #se non lo facessi mostrerebbe il nome del file,
then lstind=1			 #nel caso in cui non ci siano opzioni
fi

if [[ tpresente -eq 1 ]]
	then touch oldnames.txt
		echo oldname newname >>oldnames.txt
	fi

#### controlla i permessi della directory #######
#### in: nomecartella out: checked, perms #######
checkdir(){

	checked=0 # valore di ritorno 
	local dirname="${1}" # nome cartella

	if [[ -w "$dirname" ]] && [[ -r "$dirname" ]] && [[ -x "$dirname" ]] #rwx 
		then checked=1
	fi

}
##################################################

ignorati=0 #numro da restituire in exit
declare -a argtosearch #array degli argomenti validi

for (( i=lstind ; i <= $# ; i++ )) # scansiono gli argomenti, che vengono dopo la stringa
	do

    arg="${!i}" #indirect expansion

	if [[ -f "${arg}" ]] # arg è un file esistente 
		then
		     
    		tmparg=$(echo "${arg//[ ()@$]/_}") 
    		mv -- "$arg" "$tmparg"
			argtosearch+=(${tmparg})

	elif [[ ${rpresente} -eq 0 ]] && [[ -d "${arg}" ]] # non ho dato r ed arg è una directory
		then
			echo "${arg} e' una directory, devi usare -r"
			((ignorati += 1)) #serve per l'exit status

	elif [[ ${rpresente} -eq 0 ]] && [[ ! -f "${arg}" ]] # non dato r ed arg non è un file
		then
		 echo "${arg} non esiste"
			((ignorati += 1))

	elif [[ ${rpresente} -eq 1 ]] && [[ -d "${arg}" ]] # ho dato r e arg è una directory
    	then 
    		checkdir "${arg}" #faccio partire la funzione di controllo 
    		if [[ ${checked} -eq 1 ]] # la cartella ha i permessi giusti
				then	
					tmparg=$(echo "${arg//[ ()@$]/_}") 
					if [[ $tmparg != $arg ]]
					then
					mv  "$arg" "$tmparg"
					fi 
					argtosearch+=(${tmparg})

    		elif [[ ${checked} -eq 0 ]]
    			then echo "I permessi della directory ${arg} non sono quelli richiesti"
    			((ignorati += 1))
    		fi

	elif [[ ${rpresente} -eq 1 ]] && [[ ! -f ${arg} ]] # ho dato r e arg non è un file
		then echo "${arg} non esiste" 
			((ignorati += 1))
	fi
done

# 3) fine

##### in : nome file out: rinomina il file
rinomina(){
	
	f=$1
	dir=`dirname $1`

	if [[ tpresente -eq 1 ]]
	then echo ${f} "--->" "$(date -r ${f} +%Y%m%d_%H%M%S).${f##*.}" >> oldnames.txt
	fi
	estensione=`echo ${f##*.}`

	if [[ $estensione == $1 ]]
	then 
		mv ${f} "${dir}/$(date -r ${f} +%Y%m%d_%H%M%S)"

	elif [[ $estensione != $1 ]]
		then 
		mv ${f} "${dir}/$(date -r ${f} +%Y%m%d_%H%M%S).${f##*.}"
	fi

}

#### in: nomedir out: ricerca ricorsiva nelle directory#############
ricdirsearch(){


	for file in ${1}/* #considero anche i file nascosti
	do                                       

		local nome="${file//[ ()@$]/_}"
		if [[ "$file" != $nome ]]
		then
		mv -- "$file" "$nome"
		fi

		local nfl=`basename ${nome}`


		if [[ "$nfl" == "*" ]]
			then echo > /dev/null

		elif [[ ! -d ${nome} ]] && [[ epresente -eq 1 ]] && [[ ${nfl} =~ ${eregex} ]]
			then 
				rinomina ${nome}

		elif [[ ! -d ${nome} ]] 
			then 
				rinomina ${nome}
		
		elif [[ -d ${nome} ]] 
			then 
				checkdir "${arg}" #faccio partire la funzione di controllo 
    			if [[ ${checked} -eq 1 ]] # la cartella ha i permessi giusti
					then	
						ricdirsearch ${nome}

    			elif [[ ${checked} -eq 0 ]]
    				then echo "I permessi della directory ${arg} non sono quelli richiesti"
    					((ignorati += 1))
    			fi
				
			fi

	done
}
####################################################################



for arg in "${argtosearch[@]}" #per ogni argomento valido
do 	

	if [[ -f ${arg} ]] # se è un file rinominalo
		then
			rinomina ${arg}
	
	elif [[ -d ${arg} ]] # -r è presente, altrimenti lo script non l'avrebbe aggiunta agli argomenti 
		then 
		ricdirsearch ${arg} #passo il nome della directory
	fi

done


exit ${ignorati}
