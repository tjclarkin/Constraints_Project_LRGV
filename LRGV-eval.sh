#!/bin/bash

#Initialize SLURM
#SBATCH -J LRGV-eval
#SBATCH --time=60:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=3
#SBATCH -o LRGV-eval.out
#SBATCH --qos janus-long
#SBATCH -A UCB00000434
#SBATCH --mail-user=ticl3414@colorado.edu
#SBATCH --mail-type=END

#This script re-evaluates the decisions produced by optimization in the model.
#Must contain pareto.py, the compiled LRGV (https://github.com/tjclarkin/LRGV) and the output directory 
#from optimization.
 
#"lrgvForMOEAFramework", and all of the parameter files for LRGV AND all of the control files 
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
	
#Node Information
	nodes=1
	tasks_per_node=3
	#Be sure that these are correct in slurm lines
	
####################

#Create loops for pareto sorting
	NPROBS=${#PROBLEM[*]}
	PROBS=$(seq 1 ${NPROBS})

#Directory Information
	nfe1000=$((${NFE}/1000))
	JOB=${BASE}_${NPROBS}p_${nfe1000}k_${NSEEDS}s
	DIR=${JOB}_out
	LBOUT=${JOB}_eval.lb
	rm ${LBOUT}
	
#Evaluation Loop: Creates loadbalance script of the decision file to be re-evaluated in the model
for p in ${PROBS}
do
	CONTROL=${BASE}_${PROBLEM[p]}_eval
	FORMATTED_FILE=./${JOB}_out/${BASE}_${PROBLEM[p]}.dec
	cp ${BASE}_eval_control.txt ${CONTROL}_control.txt
	EVAL=./${DIR}/${FILEBASE}.eval
    (echo "./lrgvForMOEAFramework -m std-io -b ${CONTROL} -c combined -r ${MONTE} < ${FORMATTED_FILE} > ${EVAL}") >> ${LBOUT}	
	echo Problem ${PROBLEM[p]} appended to ${LBOUT}
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

#Remove created control files
for p in ${PROBS}
do
rm ${BASE}_${PROBLEM[p]}_eval_control.txt
done

wait

echo "Finished"
