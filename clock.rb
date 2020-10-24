def countdown_from(seconds)
  t = Time.now
  elapsed = 0

  while seconds > elapsed
    system("clear")
    print "00:#{(seconds - elapsed).to_s.rjust(2, "0")}   "
    elapsed = (Time.now - t).floor
    sleep 1
  end

  system("clear")
end

loop do
  system("clear")
  print "XX:XX   "
  gets
  countdown_from(10)
  print "00:00   "
  elapsed = nil
  start_time = Time.now
  while elapsed.nil? || elapsed.split(":").first[1].to_i < 5
    elapsed = "#{((Time.now - start_time) / 60).floor.to_s.rjust(2, "0")}:#{((Time.now - start_time) % 60).floor.to_s.rjust(2, "0")}"
    system("clear")
    print elapsed + "   "
    sleep 1
  end
  system("clear")
  print "Time!   "
  gets
end
