# NagiosPlugins
Plugins I created to fill in some gaps in monitoring
check_sm_spool.sh - A plugin to call the built in API on a smartermail server to get the number of emails in queue. 

Rquired command line options
-h The host e.g. mail.domain.com
-u Admin username
-p Admin user's password
-w number of queued emails that will trigger a warning alert
-c number of queued emails that will trigger a critical alert

Optinal command line option
-q The queue to check default | waiting | virus | spam

Returns
OK - $x messages in the $y queue. (if $x is below both thresholds)
WARNING - $x messages in the $y queue. (if $x is above the -w threshold but less than -c)
CRITICAL - $x messages in the $y queue. (if $x is above the -c threshold)
