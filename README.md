# Open3Backport

Backport of Ruby 1.9's Open3 methods, for use in Ruby 1.8.

## Installation

Add this line to your application's Gemfile:

    gem 'open3_backport'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install open3_backport

## Usage

For the most part, you can just use Open3 methods the same way you would in
Ruby 1.9. However, there is currently no support for setting environment nor
passing any of the special options that Process.spawn supports in Ruby 1.9.

Here are some examples that should work fine...

    # Block form:
    Open3.popen3("echo", "a") do |stdin, stdout, stderr, wait_thr|
      pid = wait_thr.pid # pid of the started process.
      exit_status = wait_thr.value # Process::Status object returned.
    end

    # Non-block form:
    stdin, stdout, stderr, wait_thr = Open3.popen3("echo", "a")
    pid = wait_thr[:pid]  # pid of the started process.
    stdin.close  # stdin, stdout and stderr should be closed explicitly in this form.
    stdout.close
    stderr.close
    exit_status = wait_thr.value  # Process::Status object returned.

    Open3.popen3("echo a") {|i, o, e, t| ... }

    Open3.popen3("echo", "a") {|i, o, e, t| ... }

    Open3.popen2("wc -c") do |i, o, t|
      i.print "answer to life the universe and everything"
      i.close
      p o.gets #=> "42\n"
    end

    Open3.popen2("bc -q") do |i, o, t|
      i.puts "obase=13"
      i.puts "6 * 9"
      p o.gets #=> "42\n"
    end

    Open3.popen2("dc") do |i, o, t|
      i.print "42P"
      i.close
      p o.read #=> "*"
    end

    # dot is a command of graphviz.
    graph = <<'End'
      digraph g {
      	a -> b
      }
    End
    layouted_graph, dot_log = Open3.capture3("dot -v", :stdin_data=>graph)

    o, e, s = Open3.capture3("echo a; sort >&2", :stdin_data=>"foo\nbar\nbaz\n")
    p o #=> "a\n"
    p e #=> "bar\nbaz\nfoo\n"
    p s #=> #<Process::Status: pid 32682 exit 0>

    image = File.read("/usr/share/openclipart/png/animals/mammals/sheep-md-v0.1.png", :binmode=>true)
    thumnail, err, s = Open3.capture3("convert -thumbnail 80 png:- png:-", :stdin_data=>image, :binmode=>true)
    if s.success?
      STDOUT.binmode
      print thumnail
    end

    # factor is a command for integer factorization.
    o, s = Open3.capture2("factor", :stdin_data=>"42")
    p o #=> "42: 2 3 7\n"

    # generate x**2 graph in png using gnuplot.
    gnuplot_commands = <<"End"
      set terminal png
      plot x**2, "-" with lines
      1 14
      2 1
      3 8
      4 5
      e
    End
    image, s = Open3.capture2("gnuplot", :stdin_data=>gnuplot_commands, :binmode=>true)

    # capture make log
    make_log, s = Open3.capture2e("make")

    source = "foo.c"
    Open3.popen2e("gcc", "-Wall", source) do |i, oe, t|
      oe.each do |line|
        if /warning/ =~ line
          # ...
        end
      end
    end

    Open3.pipeline_rw(["tr", "-dc", "A-Za-z"], ["wc", "-c"]) do |i, o, ts|
      i.puts "All persons more than a mile high to leave the court."
      i.close
      p o.gets #=> "42\n"
    end

    Open3.pipeline_rw("sort", "cat -n") do |stdin, stdout, wait_thrs|
      stdin.puts "foo"
      stdin.puts "bar"
      stdin.puts "baz"
      stdin.close     # send EOF to sort.
      p stdout.read   #=> "     1\tbar\n     2\tbaz\n     3\tfoo\n"
    end

    Open3.pipeline_r("zcat /var/log/apache2/access.log.*.gz",
                     [{"LANG"=>"C"}, "grep", "GET /favicon.ico"],
                     "logresolve") {|o, ts|
      o.each_line {|line|
        # ...
      }
    }

    Open3.pipeline_r("yes", "head -10") {|o, ts|
      p o.read      #=> "y\ny\ny\ny\ny\ny\ny\ny\ny\ny\n"
      p ts[0].value #=> #<Process::Status: pid 24910 SIGPIPE (signal 13)>
      p ts[1].value #=> #<Process::Status: pid 24913 exit 0>
    }

    Open3.pipeline_w("bzip2 -c", :out=>"/tmp/hello.bz2") {|i, ts|
      i.puts "hello"
    }

    # run xeyes in 10 seconds.
    Open3.pipeline_start("xeyes") {|ts|
      sleep 10
      t = ts[0]
      Process.kill("TERM", t.pid)
      p t.value #=> #<Process::Status: pid 911 SIGTERM (signal 15)>
    }

    # convert pdf to ps and send it to a printer.
    # collect error message of pdftops and lpr.
    pdf_file = "paper.pdf"
    printer = "printer-name"
    err_r, err_w = IO.pipe
    Open3.pipeline_start(["pdftops", pdf_file, "-"],
                         ["lpr", "-P#{printer}"],
                         :err=>err_w) {|ts|
      err_w.close
      p err_r.read # error messages of pdftops and lpr.
    }

    fname = "/usr/share/man/man1/ruby.1.gz"
    p Open3.pipeline(["zcat", fname], "nroff -man", "less")
    #=> [#<Process::Status: pid 11817 exit 0>,
    #    #<Process::Status: pid 11820 exit 0>,
    #    #<Process::Status: pid 11828 exit 0>]

    fname = "/usr/share/man/man1/ls.1.gz"
    Open3.pipeline(["zcat", fname], "nroff -man", "colcrt")

    # convert PDF to PS and send to a printer by lpr
    pdf_file = "paper.pdf"
    printer = "printer-name"
    Open3.pipeline(["pdftops", pdf_file, "-"],
                   ["lpr", "-P#{printer}"])

    # count lines
    Open3.pipeline("sort", "uniq -c", :in=>"names.txt", :out=>"count")

    # cyclic pipeline
    r,w = IO.pipe
    w.print "ibase=14\n10\n"
    Open3.pipeline("bc", "tee /dev/tty", :in=>r, :out=>w)
    #=> 14
    #   18
    #   22
    #   30
    #   42
    #   58
    #   78
    #   106
    #   202


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
