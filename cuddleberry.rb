require "net/ssh"
require "net/http"
require "net/scp"

def setup_authorized_keys_file
  if !File.exists? "cuddleberry_authorized_keys"
    puts
    puts "Creating 'cuddleberry_authorized_keys' file."
    puts "Enter your GitHub username to pull public keys:"
    print "> "
    user = gets.chomp
    response = Net::HTTP.get_response(URI("https://github.com/#{user}.keys"))

    if response.is_a?(Net::HTTPSuccess)
      keys = response.body
    else
      raise ArgumentError.new("Unexpected response: #{response.class}")
    end

    if keys.strip.empty?
      raise ArgumentError.new("No keys found for #{user}.")
    end

    File.write("cuddleberry_authorized_keys", keys)
  else
    puts
    puts "Using keys from existing 'cuddleberry_authorized_keys'."
  end
end

def cmds_for(task, runner:)
  case task
  when :update
    runner.call("apt-get update && apt-get upgrade -y")
  when :dhcp
    router = @ip.gsub(/\.\d+$/, ".1")
    dhcp = [
      "interface eth0",
      "static ip_address=#{@ip}/24",
      "static routers=#{router}",
      "static domain_name_servers=1.1.1.1"
    ].join("\n")
    runner.call('echo "' + dhcp + '" >> /etc/dhcpcd.conf')
  when :nfs_fstab
    path = "/var/#{@hostname}-data"
    runner.call("apt-get install -y nfs-kernel-server")
    runner.call("mkdir -p #{path}")
    runner.call('echo "/dev/sda1 '+ path + ' ext4 defaults,noatime 0 2" >> /etc/fstab')
  when :nfs_exports
    mask = @ip.gsub(/\.\d+$/, ".1/24")
    path = "/var/#{@hostname}-data"

    runner.call("apt-get install -y nfs-kernel-server")
    runner.call("mkdir -p #{path}")
    cmd = 'echo "'
    cmd << path + " "
    cmd << mask
    cmd << '(rw,sync,no_root_squash,no_subtree_check)" >> /etc/exports'
    runner.call(cmd)
  when :ssh
    cmd = "mkdir -p /home/pi/.ssh; "
    cmd << "cp /tmp/authorized_keys /home/pi/.ssh/authorized_keys; "
    cmd << "chown pi:pi -R /home/pi/.ssh; "
    cmd << "chmod 700 /home/pi/.ssh; "
    cmd << "chmod 600 /home/pi/.ssh/authorized_keys; "
    runner.call(cmd)
  when :password
    pwd = @hostname + @password_suffix
    crypt_cmd = "python3 -c 'import crypt; print(crypt.crypt(" + pwd + ", crypt.mksalt(crypt.METHOD_SHA512)))'"
    @hashed_password = runner.call(crypt_cmd)
    runner.call("printf $'pi:#{@hashed_password}' | sudo chpasswd --encrypted")
  when :hosts
    existing_hosts = runner.call('cat /etc/hosts')
    new_hosts = existing_hosts.gsub("raspberrypi", @hostname)
    runner.call('echo "' + new_hosts + '" > /etc/hosts')
  when :hostname
    existing_hostname = runner.call('cat /etc/hostname')
    new_hostname = existing_hostname.gsub("raspberrypi", @hostname)
    runner.call('echo "' + new_hostname + '" > /etc/hostname')
  else
    raise NotImplementedError.new("Unknown task: #{task}")
  end
end

def completed?(task, runner:)
  case task
  when :update
    false
  when :dhcp
    dhcpcd = runner.call("cat /etc/dhcpcd.conf")
    dhcpcd.include? @ip
  when :nfs_fstab
    return true unless @share_nfs == "y"
    configured_host = runner.call("cat /etc/hostname").strip
    runner.call("cat /etc/fstab").include? configured_host
  when :nfs_exports
    return true unless @share_nfs == "y"
    configured_host = runner.call("cat /etc/hostname").strip
    runner.call("cat /etc/exports").include? configured_host
  when :ssh
    false
  when :password
    false
  when :hosts
    !runner.call("cat /etc/hosts").include? "raspberrypi"
  when :hostname
    !runner.call("cat /etc/hostname").include? "raspberrypi"
  else
    raise NotImplementedError.new("Unknown task: #{task}")
  end
end

def generate_hostname
  filenames = Dir.glob("cuddleberry.#{@hostname_prefix}*")
  existing_hosts = filenames.map { |filename| filename.split(".").map { |parts| parts[1] } }
  used_numbers = existing_hosts.map { |hostname| hostname.gsub(@hostname_prefix, "").to_i }

  if used_numbers.empty?
    "#{@hostname_prefix}0"
  else
    "#{@hostname_prefix}#{(used_numbers.max  + 1)}"
  end
end

def setup
  local = "#{Dir.pwd}/cuddleberry_authorized_keys"
  remote = "/tmp/authorized_keys"
  result = Net::SCP.upload!(@ip, "pi", local, remote, :ssh => { :password => "raspberry" })

  # These are ordered, be careful
  tasks = %i(update dhcp nfs_fstab nfs_exports ssh password hosts hostname)

  Net::SSH.start(@ip, "pi", password: "raspberry") do |ssh|
    @hostname = generate_hostname

    runner = -> (cmd) do
      result = ssh.exec!("sudo bash -c '#{cmd}'")
      lines = result.split("\n")
      lines = lines.reject { |line| line.split.first == "bash:" || line.split.first == "sudo:" }
      result = lines.join("\n")
      result
    end

    tasks.each do |task|
      if completed?(task, runner: runner)
        puts "Skipping #{task}."
      else
        puts "Running #{task}."
        cmds_for(task, runner: runner)
      end
    end
  end
end

puts
puts "Let's cuddle some Pis! π"

setup_authorized_keys_file

puts
puts "Enter a hostname prefix, first host will be 'prefix0' (drone):"
print "> "
@hostname_prefix = gets.chomp
@hostname_prefix = "drone" if @hostname_prefix.empty?

puts
puts "Enter a password suffix, passwords will be 'hostnamesuffix' (cuddle):"
print "> "
@password_suffix = gets.chomp
@password_suffix = "cuddle" if @password_suffix.empty?

puts
puts "Share NFS? (nY):"
print "> "
@share_nfs = gets.chomp.downcase
@share_nfs = "n" if @share_nfs.empty?

ping = ""
while ping.empty?
  puts "searching for raspberrypi.local..."
  ping = `ping raspberrypi.local -c 1 | head -n 1`
end

default_ip = ping.split("(").last.split(")").first
puts default_ip
puts
puts "Enter target ip (#{default_ip}):"
print "> "
@ip = gets.chomp
@ip = default_ip if @ip.empty?

setup
