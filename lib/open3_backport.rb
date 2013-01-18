if RUBY_VERSION < "1.9"
	require 'rubygems' rescue nil
	require 'open4'
  require 'open3'
	require "open3_backport/version"
	require "open3_backport/open3"
end
