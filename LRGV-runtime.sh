#!/bin/bash

#SBATCH -J LRGV-runtime
#SBATCH --time=99:00:00
#SBATCH -N 5
#SBATCH --ntasks-per-node 12
#SBATCH -o LRGV-runtime.out
#SBATCH --qos crestone
#SBATCH -A UCB00000434
#SBATCH --mail-user=ticl3414@colorado.edu
#SBATCH --mail-type=END

#This script is for calculating hypervolumes for reference sets and calculating runtime metrics. 
#MOEAFramework-2.5 (directory) must be contained within directory.

module load jdk

##### USER ENTERED DATA #####
	BASE=LRGV
	NFE=1000000
	NSEEDS=25
#Define set of files to be reformatted for evaluation:
	PROBLEM[1]="8_c4"
	PROBLEM[2]="9_c0"

#Define number of objectives for each problem
	OBJS[1]=8
	OBJS[2]=9
	
	#Node Information
	nodes=5
	tasks_per_node=12
	
####################

#Set up information for for loops:
	NPROBS=${#PROBLEM[*]}
	PROBS=$(seq 1 ${NPROBS})
	SEEDS=$(seq 1 ${NSEEDS})

#Set up directories and job name
	nfe1000=$((${NFE}/1000))
	JOB=${BASE}_${NPROBS}p_${nfe1000}k_${NSEEDS}s
	DIR=${JOB}_out
	LBOUT=${JOB}_runtime.lb
	rm ${LBOUT}
	
#Set up Java and MOEAFramework-2.5
JAVA_ARGS="-Djava.ext.dirs=./MOEAFramework-2.5/lib -Xmx512m -classpath MOEAFramework-2.5.jar"
set -e

#Calculate runtime metrics
for p in ${PROBS}
do
	#Add hypervolume calculations for reference set to loadbalance script
	(echo "java -cp ./MOEAFramework-2.5/MOEAFramework-2.5-Demo.jar HypervolumeEval ./${JOB}_metrics/${BASE}_${PROBLEM[p]}.ref >> ${PROBLEM[p]}_HV") >> ${LBOUT}
	echo Reference set hypervolume calculations for ${PROBLEM[p]} added to ${LBOUT}
	
	for seed in ${SEEDS}
	do
		#Add runtime metrics calculations to loadbalance script for all seeds for a given problem
		(echo "java ${JAVA_ARGS} org.moeaframework.analysis.sensitivity.ResultFileEvaluator --reference ./${JOB}_metrics/${BASE}_${PROBLEM[p]}.ref --input ./${DIR}/${BASE}_${PROBLEM[p]}_s${seed}.runtime --dimension ${OBJS[p]} --output ./${JOB}_metrics/${BASE}_${PROBLEM[p]}_s${seed}_rt.metrics") >> ${LBOUT}
		echo Runtime Metrics for ${PROBLEM[p]} seed ${seed} added to ${LBOUT}.
	done
done

#Call loadbalance program to read LBOUT file 
#The lb utility load balances serial jobs by using MPI to execute each job. 
#The lb utility allows you to specify your jobs in a text file that is then read and executed across the resource you request. 
#This works on multiple nodes. You can generate the text file using any scripting language you like.
#https://github.com/ResearchComputing/lb
module load loadbalance
srun -N ${nodes} --ntasks-per-node=${tasks_per_node} lb ${LBOUT}
echo Loadbalance initating evaluations with LRGV.

wait
echo Finished