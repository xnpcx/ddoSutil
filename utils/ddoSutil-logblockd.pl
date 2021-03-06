#!/user/bin/perl -w

use Fcntl qw(:flock);
  open(SELF,"<",$0) or die "Cannot open $0 - $!";
  flock(SELF, LOCK_EX|LOCK_NB) or die "LogblockD - Already Running";

use strict;

my $config_file = "./conf/logblockd.conf";
  open CONFIG, "$config_file" or die "Program stopping, couldn't open the configuration file '$config_file'.\n";
my $config = join "", <CONFIG>;
close CONFIG;
  eval $config;
    die "Could not read the configuration file '$config_file'" if $@;

my $search_regex="$SEARCH_STRING\n";
my $ipgrab_regex="((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))(?![\\d])";

my $list_location                  = "logblockd.lst";
open LISTLOC, ">>$list_location" or die "unable to open $file $!";

if ($USE_LOGGING==1) {

	use Log::Log4perl;
	
	my $log_conf = q(
   		log4perl.rootLogger              = DEBUG, LOG1
   		log4perl.appender.LOG1           = Log::Log4perl::Appender::File
   		log4perl.appender.LOG1.filename  = /var/log/logblockd.log
   		log4perl.appender.LOG1.mode      = append
   		log4perl.appender.LOG1.layout    = Log::Log4perl::Layout::PatternLayout
   		log4perl.appender.LOG1.layout.ConversionPattern = %d %p %m %n
	);
	Log::Log4perl::init(\$log_conf);  
	my $logger = Log::Log4perl->get_logger();
}

my $bash_action="";

sub run_shell($) {
  my $argv1="$_[0]"
  $bash_action=qx"$argv1";
    if ($bash_action=="1") {
      $logger->error("run_shell returned an error.");
    }
}

$bash_action=qx'iptables -N LOGBLOCKD';
$bash_action=qx'iptables -A LOGBLOCKD -j RETURN';

open(my $log, "tail --follow=name -n0 $ACCESS_LOG |");
  while (my $line = <$log>) 
  { 
     if ($line =~ /\Q$search_regex/){
      # Get the IP address if possible.
        if ($line =~m/$ipgrab_regex/) {
          # Add them to our chain and list.
          run_shell('iptables -I LOGBLOCKD 1 -s $1 -j DROP &> /dev/null ; echo $?');
          $logger->info("Added IP address to block list: [$1]");
          my $cur_time =qx'echo $(date +"%F %T")';
            print LISTLOC "$cur_time - [$1]";
        }
        else {
          $logger->error("Block pattern matched, unable to obtain IP address");
        }
     } 


  }

