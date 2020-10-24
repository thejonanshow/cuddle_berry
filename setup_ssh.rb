require "nokogiri"
xml = `diskutil list -plist external physical`
doc = Nokogiri::XML(xml)

disks_with_boot_partition = doc.css("dict array dict").select do |dict|
  dict.css("string").map(&:text).include? "boot" 
end

disk_elements = disks_with_boot_partition.first.children.select do |child|
  child.text.match /disk/
end

disk_name = disk_elements.first.text

puts
puts "The first disk with a boot partition is #{disk_name}"
puts "****************************************************"
puts `diskutil list #{disk_name}`
puts "****************************************************"
puts "Enable ssh for #{disk_name}? (n/Y)"
print ">"

if gets.chomp.downcase == "y"
  puts `diskutil mountDisk #{disk_name}`
  `touch /Volumes/boot/ssh`
  puts "Created /Volumes/boot/ssh"
  puts `diskutil unmountDisk #{disk_name}`
else
  puts "Cancelled."
end
