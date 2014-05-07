#powershell script to backup Citrix Xenserver, inspired by Jeff Riechers vbscript http://forums.citrix.com/thread.jspa?threadID=250128
#CopyLeft jujhar@jujhar.com; feel free to modify and repost for the communities benefit
#This script comes with no warranties or guarantees, use at your own risk.
#to run simply type at the run prompt "powershell.exe -noexit c:\citrix_backups\backup_citrix.ps1
#you may have to execute "set-executionpolicy RemoteSigned" at the powershell prompt to reduce security in order for this script to run see http://www.searchmarked.com/windows/how-to-schedule-a-windows-powershell-script.php
#V2 2010-07-07

#variables to modify
$user_name="root";
$password="your_server_password";
$backup_path="c:\citrix_backups\"; #where the current script is stored and also where the backups will go
$vm_list="list_vm.txt"; #the list of the vm's you wish to back up, seperated by the new line NB they are CASE SENSITIVE
$exe="C:\Progra~2\Citrix\XenCenter\xe.exe" #if running a 64bit os then this is probably where you'll find xe.exe Otherwise it's probably in C:\Progra~1\Citrix\XenCenter\xe.exe.  NB stick with 8.3 directory convention as it saves having to put in double quotes and escaping them
$log_file=Join-Path $backup_path "backup_log.txt" #log files will also be stored here, appended to after every backup so watch it's size
$server_ip="192.168.1.30" #ip address of the pool master server (will magically pick up VM's from the other servers in the pool)
$emailFrom = "citrix_backup@jujhar.com"
$emailTo = "jujhar@jujhar.com" #backup admin email who wishes to receive  reports 
$subject = "Citrix Backup Status"
$smtpServer = "smtp.provider.com" #your smtp server

$path=Join-Path $backup_path $vm_list;
$file_contents_size=get-content $path | measure-object -line;
$file_contents=Get-Content $path;
$current_server_name="";
$guid="";
$newline_char="`n" # \n
$output="$newline_char"; #variable stores all output for log files and email
$current_time=Get-Date;
$output+="***************************************************************** $newline_char";
$output+="Starting to backup up all VM's @ $current_time $newline_char";
$output+="***************************************************************** $newline_char";
$output+="$newline_char";
$this_iteration_output="";

$total_time_taken=Measure-Command{
	foreach ($current_server_name in $file_contents)	{	
		$this_iteration_output+="++++++---------------------* START $current_server_name *---------------------++++++ $newline_char";
		$this_iteration_output+="Backing up $current_server_name via $server_ip $newline_char";
		$current_time=Get-Date;		
		$this_iteration_output+="Starting @ $current_time $newline_char";
		$guid=&$exe -s $server_ip -u $user_name -pw $password vm-list name-label=$current_server_name --minimal; #get guid of server based on the name you supply in the text file
		if ($guid -ne ""){ #if guid is not empty then back the vm		
			$time_taken=Measure-Command {
				
				$guid=&$exe -s $server_ip -u $user_name -pw $password vm-snapshot new-name-label=backup uuid=$guid; #generate vm-snapshot and return it's guid
				$this_iteration_output+="$result $newline_char";
				
				$backup_filename=$backup_path + $current_server_name+".xva";
				$result=&$exe -s $server_ip -u $user_name -pw $password template-export template-uuid=$guid filename=$backup_filename; #backup vm
				$this_iteration_output+="$result $newline_char";
				
				$result=&$exe -s $server_ip -u $user_name -pw $password template-uninstall template-uuid=$guid --force; #remove snapshot from server
				$this_iteration_output+="$result $newline_char";
			}
			$this_iteration_output+="Time taken: $time_taken $newline_char";
		}	
		else {
			$this_iteration_output+="Can't find VM $current_server_name $newline_char";
		}
		$current_time=Get-Date;
		$this_iteration_output+="Finished $current_server_name @ $current_time $newline_char";
		$this_iteration_output+="++++++---------------------* FINISH $current_server_name *---------------------++++++ $newline_char";
		$this_iteration_output+="$newline_char";
		Echo $this_iteration_output; #output this to the screen as well to give some feedback to the console
		$output+=$this_iteration_output; #append to final output
	}
}
$current_time=Get-Date;
$output+="***************************************************************** $newline_char";
$output+="Finished backing up all VM's @ $current_time $newline_char";
$output+="Total Time Taken: $total_time_taken $newline_char";
$output+="***************************************************************** $newline_char";
$output+="$newline_char";
$output+="$newline_char";
Echo $output; #output this to the screen as well to give some feedback to the console

#send email to administrator with logs
$body = $output;
$smtp = new-object Net.Mail.SmtpClient($smtpServer)
$smtp.Send($emailFrom, $emailTo, $subject, $body)
