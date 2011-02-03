#!/usr/bin/ruby1.9.1

require 'highline/import'
require 'yaml'
require 'net/smtp'

$t0          = Time.now
$repoURL     = "http://pudge.yourdomain1.com/svn/www/branches/0.2"
$sandbox     = "sandbox"
$dest        = "/www"
$domain      = ".yourdomain2.com"
$rollback    = "/rollback"
$sleepTime   = 1


$dryrun   = false
$checkLighttpdTimes = 3
$verbose = 1

#derived $vars
$ts          = $t0.to_s.split(" ") * "_"
$log         = "logs/synclog_#{$ts}.log"
$logo        = "#{$dest}/static#{$domain}/imgs/_global/logo.png"
$rollbackAdd = "#{$rollback}/#{$ts}"
$fingerprint = "#{$dest}/static#{$domain}/omnisyncRev.yml.txt"

def send_email(from, from_alias, to, to_alias, subject, message)
  msg = <<END_OF_MESSAGE
From: #{from_alias} <#{from}>
To: #{to_alias} <#{to}>
Subject: #{subject}

#{message}
END_OF_MESSAGE

  Net::SMTP.start('localhost') do |smtp|
    smtp.send_message msg, from, to
  end
end


#color output
class Co
  def self.puts(str, color=':green')
    if str.class == Array
      str=str.join("\n")
    end
    if str.class == String
      str = str.gsub(/'/, '')
    end
    begin
      if $verbose>0
        say("<%= color('#{str}', #{color}) %>")
      end
    rescue NameError
      puts "NameError, original str = #{str}"
      #do nothing, unkonwn problem
     end
  end

end

class Omnisync
  def self.getRepoRev
    @@res ||= `svn log -r 'HEAD' #{$repoURL}`.split("\n")[1].split(" ")[0]
  end

  def self.getIp
    ifconfig = `ifconfig`
    lines = ifconfig.split("\n")
    ipaddress = lines[1].split(":")[1].split(" ")[0].strip
  end
  
  def log(cmd, out)
    @@logStarted ||= `echo '!!! omnisync2 started @ ***#{$ts}***' >> #{$log}`
    writeToLog "#{cmd} => #{out}\n"
  end

  def writeToLog str
    @fh ||= File.open($log, "a") 
    tsnow = Time.now.to_s.split(" ") * "_"
    @fh.write "[#{tsnow}] [#{str}]"
  end
  
  def message(msg, color=':green')
    @steps ||= 1
    Co.puts "#{@steps.to_s}. " + msg, color 
    writeToLog msg
    @steps = @steps + 1
  end

  def runCmd(cmd)
    out = nil
    unless $dryrun 
      out = `#{cmd}`
    end
    log(cmd, out)
  end

  def getCurrSVNRev
    ver = 0
    begin
      ver = YAML::load(File.open $fingerprint)[:svn]
    rescue => e
    
    end
    ver
  end

  def backupWWW
    message "Backing up #{$dest} to #{$rollbackAdd}_#{getCurrSVNRev}", ":cyan"
    runCmd "mkdir -p #{$rollback}; cp -r #{$dest} #{$rollbackAdd}"
  end

  def rmSandbox
    message "Removing Old SandBox..."
    @@lastSize  = `du -sk #{$sandbox}`.split("\t").first.to_i
    runCmd "rm -rf #{$sandbox}"
  end

  def coSandbox
    message "Exporting SVN to SandBox..."

    #threaded checkout
    tPrint = nil
    tExport = Thread.new do 
      runCmd "svn export #{$repoURL} #{$sandbox}"
      tPrint.kill
    end

    tPrint  = Thread.new do
      sizeLast = 0
      
      while true
        begin
          sleep $sleepTime
          sizeCurr = `du -sk #{$sandbox}`.strip.split("\t").first.to_i
          speedRaw = ((sizeCurr - sizeLast) / $sleepTime)
          speed = speedRaw.floor.to_s + " kB/s"
          sizeLast = sizeCurr
          sizeNow, sandboxDir = `du -skh #{$sandbox}`.strip.split("\t")
          eta = ((@@lastSize - sizeCurr )/speedRaw).ceil.to_s + " sec"
        
          Co.puts "#{sandboxDir}\t size = #{sizeNow}\t speed = #{speed}\t ETA = #{eta}", ":yellow"
        rescue

        end
      end
    end

    tExport.join
    tPrint.join 
  end

  def renameSandbox(folders)
    message "Renaming SandBox Names..."
    folders.each{|f| runCmd "mv #{$sandbox}/#{f} #{$sandbox}/#{f}#{$domain}"}
  end

  def rsyncSandbox (folders)
    message "Rsyncing Folders from Sandbox to /www..."
    folders.each{|f| runCmd "rsync -zav --delete --times --recursive --exclude-from 'excludes.txt' #{$sandbox}/#{f}#{$domain} #{$dest}"}
  end
  
  def fixperm
    message "Fixing Permissions under /www/..."
    runCmd "chgrp -R www-data #{$dest}"
    runCmd "chmod -R g+w #{$dest}" 
    runCmd "chmod -R g+x /www/clients.yourdomain2.com/"
    runCmd "chmod -R +x /www/www.yourdomain2.com/vendors"
    runCmd "chmod 644 /www/support.yourdomain2.com/include/ost-config.php"
    #runCmd "chmod g+w /www/www.yourdomain2.com/app/tmp/logs/errors.log"
  end

  def anotateLogo
    message "Anotating Logo..."
    rev = "#{Omnisync.getRepoRev} # TEST"
    ip = "IP = #{Omnisync.getIp}"
    synced = "Synced @ #{Time.now.to_s.split(" ").slice(0..1) * " "}"

    runCmd "gm convert  -negate #{$logo} #{$logo}"
    runCmd "gm convert -font helvetica -fill red -draw \"text 5,20 '#{rev}'\" -pointsize 24 #{$logo} #{$logo}"
    runCmd "gm convert -font helvetica -fill yellow -draw \"text 5,37 '#{ip}'\" -pointsize 16 #{$logo} #{$logo}"
    runCmd "gm convert -font helvetica -fill white -draw \"text 5,52 '#{synced}'\" -pointsize 9 #{$logo} #{$logo}"
  end

  def flushCache
    message "Flushing caches under /www/www.yourdomain2.com..."
    runCmd "mkdir -p /www/www.yourdomain2.com/app/cache"
    runCmd "cd /www/www.yourdomain2.com/app/cache; rm -rf *"

    runCmd "mkdir -p /www/www.yourdomain2.com/app/views/cache"
    runCmd "cd /www/www.yourdomain2.com/app/views/cache; rm -rf *"

    runCmd "cd /www/www.yourdomain2.com/club/bbs/forumdata/templates/; rm *"
  end
  
  def syncManage
    message "Synchronising /www/manage.yourdomain2.com (TEST only)...", ":red"
    runCmd "cd /www/manage.yourdomain2.com; svn up"
    runCmd "mkdir -p /www/manage.yourdomain2.com/app/cache"
    runCmd "cd /www/manage.yourdomain2.com/app/cache; rm -rf *"
    runCmd "mkdir -p /www/manage.yourdomain2.com/app/views/cache"
    runCmd "cd /www/manage.yourdomain2.com/app/views/cache; rm -rf *"
  end

  def restartLighttpd
    message "Restarting Lighttpd server..."
    runCmd "service lighttpd restart"
    
    $checkLighttpdTimes.times do |t|
      #maybe add some checking
    end
  end

  def restartMemcached
    message "Restarting Memcached server..."
    runCmd "service memcached restart"
  end

  def tagSVNrev
    tagInfoYaml = {:ts=>$ts, :svn=>Omnisync.getRepoRev}.to_yaml
    message "Writing SVN revsion to #{$fingerprint}"

    begin
      fh = File.open($fingerprint, "w") {|f| f.write tagInfoYaml}
    rescue  => e
      message "Error in writing rev file. #{e}", ":red"
    end
  end

  def sanityCheck
    message "Sanity Checking ... "
  
  end

  def finish
    $t1 = Time.now
    $ts = $t1 - $t0
    message "All Finished in #{$ts.ceil} seconds."
  end

end

#### work start here
$server   = (Omnisync.getIp =~ /^10\.1\.1\.[0-9]{1,3}$/).nil? ? "LIVE" : "TEST"
$toEmails = $SERVER == "LIVE" ? "111@alist.com","222@blist.com"




omni=Omnisync.new
omni.message "Welcome Omnisync2 #{$server} started. Syncing SVN #{omni.getCurrSVNRev} to #{Omnisync.getRepoRev}\n   Session log => #{$log}\n   Please wait for a few minutes... ", ":magenta"
omni.rmSandbox
omni.coSandbox
omni.backupWWW

omni.renameSandbox(["www", "help", "static", "clients", "support"])
omni.rsyncSandbox(["www", "help", "static", "clients", "support"])

omni.flushCache

if $server == "TEST"
  omni.anotateLogo
  omni.syncManage
end

omni.tagSVNrev

omni.fixperm
#omni.restartLighttpd
omni.restartMemcached
omni.sanityCheck



omni.message("Sending Report Email...")
begin
  $toEmails.split(",").each do |email|
    send_email("bot@yourdomain1.com", "Omnisync2 Bot", email.strip, "", "#{$server} Omnisync2 Sync Reports #{$ts}", File.open($log, "r").read)
  end
rescue => e
  puts e
end

omni.finish
