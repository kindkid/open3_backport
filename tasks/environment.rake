desc "Load the environment"
task :environment do
  require File.expand_path('../../lib/open3_backport', __FILE__)
end
