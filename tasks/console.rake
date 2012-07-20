desc "Open development console"
task :console do
  puts "Loading console..."
  system "irb -r #{File.join('.','lib','open3_backport')}"
end
