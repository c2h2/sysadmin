require 'whois'
require 'resolv'

BAN_IP="180.168.41.175"  #china telecom makes everything to this ip when no A record..
RETRY_TIMES=3
list = File.read(ARGV[0]).lines

class DnsCheck
  attr_reader :host
  def initialize(host)
    @host = host
  end

  def a
    @a ||= Resolv::DNS.new.getresources(host, Resolv::DNS::Resource::IN::A)
  end

  def a?
    a.any?
  end

  def mx
    @mx ||= Resolv::DNS.new.getresources(host, Resolv::DNS::Resource::IN::MX)
  end

  def mx?
    mx.any?
  end

  def ns
    @ns ||= Resolv::DNS.new.getresources(host, Resolv::DNS::Resource::IN::NS)
  end

  def ns?
    ns.any?
  end

  def get_ip _retry=RETRY_TIMES
    return BAN_IP if _retry == 0

    begin
      return IPSocket::getaddress host
    rescue
      return get_ip(_retry - 1)
    end 
    
  end
end

def get_whois site, _retry=RETRY_TIMES
  return nil if _retry==0
  begin
    Whois.whois(site).to_s
  rescue
    return get_whois(site, _retry - 1)
  end
end

#list = ["ada.com","asdf.com", "asdf.cc", "asdf.cn", "asdf.ch", "asdf.it"]
#list = ["aklhsdflkajsdf.cc"]
#Whois.whois("abc.ch").to_s

def site_info_2text site, text
  if text.nil?
    return "** #{site} Query Whois failed."
  end 

  days_remain = -1
  text.lines.each do |l|
    if l.include?("Registration Expiration Date") or l.include?("Expiry Date")
      dstr=l.split(" ").last
      days_remain = Date.parse(dstr) - Date.today
      break
    elsif l.include?("Expiration Time")
      dstr=l.split("Time:").last
      days_remain = Date.parse(dstr) - Date.today
    end
  end
  if days_remain == -1
    res = DnsCheck.new(site).get_ip
    if res == BAN_IP
      return "** #{site} may be available. Whois and IP check failed."
    else
      return "** #{site} whois failed, but ip = #{res}"
    end
  else
    return "** #{site}".ljust(15) + days_remain.to_i.to_s.ljust(5) + "days Remaining. "
  end
end


list.each do |dn|
  dn = dn.strip
  text=get_whois(dn)
  puts site_info_2text(dn, text)
end

