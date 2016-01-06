#!/bin/bash

#Initialize SLURM
#SBATCH -J 9_c0
#SBATCH --time=85:00:00
#SBATCH --nodes=3
#SBATCH --ntasks-per-node=12
#SBATCH -o 9_c0.out
#SBATCH --qos crestone
#SBATCH -A UCB00000434
#SBATCH --mail-user=ticl3414@colorado.edu
#SBATCH --mail-type=END

#STEP 1 for AGU: This is the optimization script for AGU research. 
#Requires lrgvForMOEAFramework in the directory and borg to be compiled and renamed to borg-1.8e.exe.

##### USER ENTERED DATA #####

#PROBLEM INFORMATION
	BASE=LRGV
	#Problems
	NPROBS=2
	PROBLEM[2]="9_c0"
	p=2
	#And constrains per problem
	CONSTRAINT[2]=0
	#Number of Objectives per problem
	OBJS[2]=9
	#Epsilons
	#rel critrel numleases surplus drop cost cvar drtranscost	
	EPS[1]="0.002,0.0005,0.013,0.06,0.011,0.006,0.001,0.0045"  #Ten "boxes" for each objective
	#rel critrel numleases surplus drop cost cvar drtranscost drvuln	
	EPS[2]="0.11,0.078,0.045,0.073,0.017,0.011,0.01,0.012,0.025" #Five "boxes" for each objective

#BORG INFORMATION
	LOW=(0,0,0,0.1,0,0,0,0)
	UP=(1,1,1,0.4,3,3,3,3)
	NFE=1000000
	FREQ=50000
	NSEEDS=25

#LRGV INFORMATION
	MONTE=1000

#Node Information
	nodes=3
	tasks_per_node=12
	#Be sure that these are correct in slurm lines
	
####################

#Create loops for optimization
	SEEDS=$(seq 1 ${NSEEDS})
	
#Define Job and create directory
	#Changing NFE to thousands
	nfe1000=$((${NFE}/1000))
	JOB=${BASE}_${NPROBS}p_${nfe1000}k_${NSEEDS}s
	DIR=${JOB}_out
	#mkdir ${DIR}
	echo Base set to ${BASE} and ${DIR} directory created.
	echo Analyzing: ${PROBLEM[@]} with ${CONSTRAINT[@]} constraints, respectively.
	echo Borg set with Lower Limits: ${LOW} Upper Limits: ${UP} 
	echo Epsilons:
	echo	${PROBLEM[p]} : ${EPS[p]}
	echo Frequency: ${FREQ} LRGV set with Monte Carlo: ${MONTE}
	
#Set file for loadbalance input file and remove previous version.
LBOUT=${JOB}_${p}.lb
rm ${LBOUT}
echo Creating ${LBOUT}

#For loop to create code to run with loadbalance. Outer loop cycles through selected problems. Inner loop cycles through selected seeds.
FILEBASE=${BASE}_${PROBLEM[p]}
echo Filebase set to ${FILEBASE}
echo Problem ${PROBLEM[p]} with ${CONSTRAINT[p]} constraints being written to ${LBOUT}
	
#For loop to run through all selected seeds.
for seed in ${SEEDS}
	do
	#Command line to write Borg MOEA command line to LBOUT file. 
	#NOTE: printbar in frontend.c has been removed prior to compiling. borg.exe has been renamed to borg-1.8e.exe
	(echo "./borg-1.8e.exe -v 8 -o ${OBJS[p]} -c ${CONSTRAINT[p]} -R ${DIR}/${FILEBASE}_s${seed}.runtime -F ${FREQ} -f ${DIR}/${FILEBASE}_s${seed}.set -l ${LOW} -u ${UP} -e ${EPS[p]} -n ${NFE} -s ${seed} -- ./lrgvForMOEAFramework -m std-io -b ${FILEBASE} -c combined -r ${MONTE}") >> ${LBOUT}
	#Check to see which have begun
	echo ${PROBLEM[p]} seed ${seed} written to ${LBOUT}
done

#Call loadbalance program to read LBOUT file 
#The lb utility load balances serial jobs by using MPI to execute each job. 
#The lb utility allows you to specify your jobs in a text file that is then read and executed across the resource you request. 
#This works on multiple nodes. You can generate the text file using any scripting language you like.
#https://github.com/ResearchComputing/lb
module load loadbalance
srun -N ${nodes} --ntasks-per-node=${tasks_per_node} lb ${LBOUT}
echo "${JOB} begun."

wait
echo "Finished"
