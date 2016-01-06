#!/bin/bash

#Initialize SLURM
#SBATCH -J LRGV-pareto
#SBATCH --time=1:00:00
#SBATCH --nodes=1
#SBATCH -o LRGV-pareto.out
#SBATCH --qos janus-debug
#SBATCH -A UCB00000434
#SBATCH --mail-user=ticl3414@colorado.edu
#SBATCH --mail-type=END

#STEP 2 for AGU: This script pareto sorts results from optimization and creates the reference set required for calculating runtime
#metrics and the decision file required for reevaluating the solutions in the LRGV model.
#Must contain pareto.py, the compiled LRGV (https://github.com/tjclarkin/LRGV) and the output directory 
#from optimization, "lrgvForMOEAFramework", and all of the parameter files for LRGV AND all of the control files 
module load python/anaconda-2.1.0

##### USER ENTERED DATA #####

#PROBLEM INFORMATION
	BASE=LRGV
	NFE=1000000
	NSEEDS=25
	MONTE=1000
	
#Define set of files to be reformatted for evaluation:
	PROBLEM[1]="8_c4"
	PROBLEM[2]="9_c0"

#Define number of objectives for each problem
	OBJS[1]=8
	OBJS[2]=9
	
	#Epsilons
	#rel critrel numleases surplus drop cost cvar drtranscost	
	EPS[1]="0.004 0.001 0.03 0.12 0.021 0.012 0.002 0.009"  #Five "boxes" for each objective
	#rel critrel numleases surplus drop cost cvar drtranscost drvuln	
	EPS[2]="0.11 0.078 0.045 0.073 0.017 0.011 0.01 0.012 0.025" #Five "boxes" for each objective
		
####################

#Create loops for pareto sorting
	NPROBS=${#PROBLEM[*]}
	PROBS=$(seq 1 ${NPROBS})

#Directory Information
	nfe1000=$((${NFE}/1000))
	JOB=${BASE}_${NPROBS}p_${nfe1000}k_${NSEEDS}s
	DIR=${JOB}_out
	mkdir ${JOB}_metrics
	
#Step 1: Pareto sort the ouput set files from optimization
for p in ${PROBS}
do
	FILEBASE=${BASE}_${PROBLEM[p]}

	#Set correct epsilons for number of objectives
	if [ ${OBJS[p]} == 8 ]
	then
		OBJECTIVES="8-15"
	elif [ ${OBJS[p]} == 9 ]
	then
		OBJECTIVES="8-16"
	else
		echo Invalid objective count.
		exit
	fi

	python pareto.py \
			./${DIR}/${FILEBASE}_s*.set \
			-o ${OBJECTIVES} \
			-e ${EPS[p]} \
			--output ./${DIR}/${FILEBASE}.pareto \
			--delimiter=' ' \
			--blank \
			--comment="#" \
			--contribution \
			--line-number

#Step 2: Seperate out the (a) objectives and (b) decisions:

#(a) Extract objectives from pareto set. sed is used to remove rows beginning with # from FILE and cut is used to extract objectives
	#Set appropriate columns depending on which problem's objectives are being extracted
	if [ ${OBJS[p]} == 8 ]
	then
		OBJECTIVES="9-16"
	elif [ ${OBJS[p]} == 9 ]
	then
		OBJECTIVES="9-17"
	else
		echo Invalid objective count.
		exit
	fi
	
	#Extract objectives to create the reference set
	FILE=./${DIR}/${FILEBASE}.pareto
	FORMATTED_FILE=./${JOB}_metrics/${FILEBASE}.ref
	sed '/^#/ d' < ${FILE} | cut -d " " -f ${OBJECTIVES} > ${FORMATTED_FILE}
	echo Objectives from ${FILE} exported to ${FORMATTED_FILE}

#(b) Extract decisions from pareto set. sed is used to remove rows beginning with # from FILE and cut is used to extract decisions (columns 1-8) of a " " delimite file to FORMATTED_FILE.

	FILE=./${DIR}/${FILEBASE}.pareto
	FORMATTED_FILE=./${DIR}/${FILEBASE}.dec
	sed '/^#/ d' < ${FILE} | cut -d " " -f 1-8 > ${FORMATTED_FILE}
	echo ${FILE} reformatted and exported to ${FORMATTED_FILE}
done

wait

echo "Finished"
