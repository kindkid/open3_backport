#
# = open3.rb: Popen, but with stderr, too
#
# Author:: Yukihiro Matsumoto, backport by Chris Johnson
# Documentation:: Konrad Meyer, backport by Chris Johnson
#
# Open3 gives you access to stdin, stdout, and stderr when running other
# programs.
#

#
# Open3 grants you access to stdin, stdout, stderr and a thread to wait the
# child process when running another program.
#
# - Open3.popen3 : pipes for stdin, stdout, stderr
# - Open3.popen2 : pipes for stdin, stdout
# - Open3.popen2e : pipes for stdin, merged stdout and stderr
# - Open3.capture3 : give a string for stdin.  get strings for stdout, stderr
# - Open3.capture2 : give a string for stdin.  get a string for stdout
# - Open3.capture2e : give a string for stdin.  get a string for merged stdout and stderr
# - Open3.pipeline_rw : pipes for first stdin and last stdout of a pipeline
# - Open3.pipeline_r : pipe for last stdout of a pipeline
# - Open3.pipeline_w : pipe for first stdin of a pipeline
# - Open3.pipeline_start : a pipeline
# - Open3.pipeline : run a pipline and wait
#

module Open3

  def detach(pid) # :nodoc:
    thread = Process.detach(pid)
    thread[:pid] = pid
    thread.instance_eval do

      def pid
        self[:pid]
      end

      alias :old_value :value

      def value(*args)
        wait_for_process_to_finish
        old_value(*args)
      end

      def wait_for_process_to_finish
        return if @waited
        Process.waitpid(pid)
        wakeup
        @waited = true
      rescue
        # Ignore
      end

    end
    thread
  end
  module_function :detach
  class << self
    private :detach
  end

  #
  # Open stdin, stdout, and stderr streams and start external executable.
  # In addition, a thread for waiting the started process is noticed.
  # The thread has a pid method and thread variable :pid which is the pid of
  # the started process.
  #
  # Block form:
  #
  #   Open3.popen3(cmd...) {|stdin, stdout, stderr, wait_thr|
  #     pid = wait_thr.pid # pid of the started process.
  #     ...
  #     exit_status = wait_thr.value # Process::Status object returned.
  #   }
  #
  # Non-block form:
  #
  #   stdin, stdout, stderr, wait_thr = Open3.popen3(cmd...)
  #   pid = wait_thr[:pid]  # pid of the started process.
  #   ...
  #   stdin.close  # stdin, stdout and stderr should be closed explicitly in this form.
  #   stdout.close
  #   stderr.close
  #   exit_status = wait_thr.value  # Process::Status object returned.
  #
  # So a commandline string and list of argument strings can be accepted as follows.
  #
  #   Open3.popen3("echo", "a") {|i, o, e, t| ... }
  #
  # wait_thr.value waits the termination of the process.
  # The block form also waits the process when it returns.
  #
  # Closing stdin, stdout and stderr does not wait the process.
  #
  def popen3(*cmd)
    if block_given?
      begin
        pid, stdin, stdout, stderr = Open4::popen4(*cmd)
        wait_thr = detach(pid)
        stdin.sync = true
        return yield(stdin, stdout, stderr, wait_thr)
      ensure
        stdin.close unless stdin.nil? || stdin.closed?
        stdout.close unless stdout.nil? || stdout.closed?
        stderr.close unless stderr.nil? || stderr.closed?
        wait_thr.value unless wait_thr.nil?
      end
    else
      pid, stdin, stdout, stderr = Open4::popen4(*cmd)
      stdin.sync = true
      return [stdin, stdout, stderr, detach(pid)]
    end
  end
  module_function :popen3

  # Open3.popen2 is similer to Open3.popen3 except it doesn't make a pipe for
  # the standard error stream.
  #
  # Block form:
  #
  #   Open3.popen2(cmd...) {|stdin, stdout, wait_thr|
  #     pid = wait_thr.pid # pid of the started process.
  #     ...
  #     exit_status = wait_thr.value # Process::Status object returned.
  #   }
  #
  # Non-block form:
  #
  #   stdin, stdout, wait_thr = Open3.popen2(cmd...)
  #   ...
  #   stdin.close  # stdin and stdout should be closed explicitly in this form.
  #   stdout.close
  #
  # Example:
  #
  #   Open3.popen2("wc -c") {|i,o,t|
  #     i.print "answer to life the universe and everything"
  #     i.close
  #     p o.gets #=> "42\n"
  #   }
  #
  #   Open3.popen2("bc -q") {|i,o,t|
  #     i.puts "obase=13"
  #     i.puts "6 * 9"
  #     p o.gets #=> "42\n"
  #   }
  #
  #   Open3.popen2("dc") {|i,o,t|
  #     i.print "42P"
  #     i.close
  #     p o.read #=> "*"
  #   }
  #
  def popen2(*cmd)
    if block_given?
      popen3(*cmd) do |i, o, e, t|
        e.close
        yield(i, o, t)
      end
    else
      i, o, e, t = popen3(*cmd)
      e.close
      return [i, o, t]
    end
  end
  module_function :popen2

  # Open3.popen2e is similer to Open3.popen3 except it merges
  # the standard output stream and the standard error stream.
  #
  # Block form:
  #
  #   Open3.popen2e(cmd...) {|stdin, stdout_and_stderr, wait_thr|
  #     pid = wait_thr.pid # pid of the started process.
  #     ...
  #     exit_status = wait_thr.value # Process::Status object returned.
  #   }
  #
  # Non-block form:
  #
  #   stdin, stdout_and_stderr, wait_thr = Open3.popen2e(cmd...)
  #   ...
  #   stdin.close  # stdin and stdout_and_stderr should be closed explicitly in this form.
  #   stdout_and_stderr.close
  #
  # Example:
  #   # check gcc warnings
  #   source = "foo.c"
  #   Open3.popen2e("gcc", "-Wall", source) {|i,oe,t|
  #     oe.each {|line|
  #       if /warning/ =~ line
  #         ...
  #       end
  #     }
  #   }
  #
  def popen2e(*cmd)
    if block_given?
      popen3(*cmd) do |i, o, e, t|
        yield(i, merged_read_stream(o, e), t)
      end
    else
      i, o, e, t = popen3(*cmd)
      return [i, merged_read_stream(o, e), t]
    end
  end
  module_function :popen2e

  def merged_read_stream(*streams) # :nodoc:
    raise NotImplementedError
  end

  # Open3.capture3 captures the standard output and the standard error of a command.
  #
  #   stdout_str, stderr_str, status = Open3.capture3(cmd... [, opts])
  #
  # The cmd arguments are passed to Open3.popen3.
  #
  # If opts[:stdin_data] is specified, it is sent to the command's standard input.
  #
  # If opts[:binmode] is true, internal pipes are set to binary mode.
  #
  # Example:
  #
  #   # dot is a command of graphviz.
  #   graph = <<'End'
  #     digraph g {
  #       a -> b
  #     }
  #   End
  #   layouted_graph, dot_log = Open3.capture3("dot -v", :stdin_data=>graph)
  #
  #   o, e, s = Open3.capture3("echo a; sort >&2", :stdin_data=>"foo\nbar\nbaz\n")
  #   p o #=> "a\n"
  #   p e #=> "bar\nbaz\nfoo\n"
  #   p s #=> #<Process::Status: pid 32682 exit 0>
  #
  #   # generate a thumnail image using the convert command of ImageMagick.
  #   # However, if the image stored really in a file,
  #   # system("convert", "-thumbnail", "80", "png:#{filename}", "png:-") is better
  #   # because memory consumption.
  #   # But if the image is stored in a DB or generated by gnuplot Open3.capture2 example,
  #   # Open3.capture3 is considerable.
  #   #
  #   image = File.read("/usr/share/openclipart/png/animals/mammals/sheep-md-v0.1.png", :binmode=>true)
  #   thumnail, err, s = Open3.capture3("convert -thumbnail 80 png:- png:-", :stdin_data=>image, :binmode=>true)
  #   if s.success?
  #     STDOUT.binmode; print thumnail
  #   end
  #
  def capture3(*cmd)
    if Hash === cmd.last
      opts = cmd.pop.dup
    else
      opts = {}
    end

    binmode = opts[:binmode]
    i_data = (opts[:stdin_data] || '').to_s
    o_data = ''
    e_data = ''

    popen3(*cmd) do |i, o, e, t|
      if binmode
        i.binmode
        o.binmode
        e.binmode
      end

      i_complete = i_data.empty?
      o_complete = false
      e_complete = false

      until i_complete && o_complete && e_complete
        i_blocked = false
        o_blocked = false
        e_blocked = false

        unless i_complete
          begin
            bytes_written = i.write_nonblock(i_data)
            if bytes_written == i_data.length
              i.close
              i_complete = true
            else
              i_data = i_data[bytes_written .. -1]
            end
          rescue Errno::EWOULDBLOCK, Errno::EAGAIN, Errno::EINTR
            i_blocked = true
          end
        end

        unless o_complete
          begin
            o_data << o.read_nonblock(CAPTURE_BUFFER_SIZE)
          rescue Errno::EWOULDBLOCK, Errno::EAGAIN
            o_blocked = true
          rescue EOFError
            raise unless i_complete
            o.close
            o_complete = true
          end
        end

        unless e_complete
          begin
            e_data << e.read_nonblock(CAPTURE_BUFFER_SIZE)
          rescue Errno::EWOULDBLOCK, Errno::EAGAIN
            e_blocked = true
          rescue EOFError
            raise unless i_complete
            e.close
            e_complete = true
          end
        end

        if i_blocked && o_blocked && e_blocked
          IO.select([o, e], [i], [o,e,i])
        end
      end
      return [o_data, e_data, t.value]
    end
  end
  module_function :capture3

  # Open3.capture2 captures the standard output of a command.
  #
  #   stdout_str, status = Open3.capture2(cmd... [, opts])
  #
  # The cmd arguments are passed to Open3.popen3.
  #
  # If opts[:stdin_data] is specified, it is sent to the command's standard input.
  #
  # If opts[:binmode] is true, internal pipes are set to binary mode.
  #
  # Example:
  #
  #   # factor is a command for integer factorization.
  #   o, s = Open3.capture2("factor", :stdin_data=>"42")
  #   p o #=> "42: 2 3 7\n"
  #
  #   # generate x**2 graph in png using gnuplot.
  #   gnuplot_commands = <<"End"
  #     set terminal png
  #     plot x**2, "-" with lines
  #     1 14
  #     2 1
  #     3 8
  #     4 5
  #     e
  #   End
  #   image, s = Open3.capture2("gnuplot", :stdin_data=>gnuplot_commands, :binmode=>true)
  #
  def capture2(*cmd)
    if Hash === cmd.last
      opts = cmd.pop.dup
    else
      opts = {}
    end

    binmode = opts[:binmode]
    i_data = (opts[:stdin_data] || '').to_s
    o_data = ''

    popen3(*cmd) do |i, o, e, t|
      e.close
      if binmode
        i.binmode
        o.binmode
        e.binmode
      end

      i_complete = i_data.empty?
      o_complete = false

      until i_complete && o_complete
        i_blocked = false
        o_blocked = false

        unless i_complete
          begin
            bytes_written = i.write_nonblock(i_data)
            if bytes_written == i_data.length
              i.close
              i_complete = true
            else
              i_data = i_data[bytes_written .. -1]
            end
          rescue Errno::EWOULDBLOCK, Errno::EAGAIN, Errno::EINTR
            i_blocked = true
          end
        end

        unless o_complete
          begin
            o_data << o.read_nonblock(CAPTURE_BUFFER_SIZE)
          rescue Errno::EWOULDBLOCK, Errno::EAGAIN
            o_blocked = true
          rescue EOFError
            raise unless i_complete
            o.close
            o_complete = true
          end
        end

        if i_blocked && o_blocked && e_blocked
          IO.select([o], [i], [o,i])
        end
      end
      return [o_data, t.value]
    end
  end
  module_function :capture2

  # Open3.capture2e captures the standard output and the standard error of a command.
  #
  #   stdout_and_stderr_str, status = Open3.capture2e(cmd... [, opts])
  #
  # The cmd arguments are passed to Open3.popen3.
  #
  # If opts[:stdin_data] is specified, it is sent to the command's standard input.
  #
  # If opts[:binmode] is true, internal pipes are set to binary mode.
  #
  # Example:
  #
  #   # capture make log
  #   make_log, s = Open3.capture2e("make")
  #
  def capture2e(*cmd)
    if Hash === cmd.last
      opts = cmd.pop.dup
    else
      opts = {}
    end

    binmode = opts[:binmode]
    i_data = (opts[:stdin_data] || '').to_s
    oe_data = ''

    popen3(*cmd) do |i, o, e, t|
      if binmode
        i.binmode
        o.binmode
        e.binmode
      end

      i_complete = i_data.empty?
      o_complete = false
      e_complete = false

      until i_complete && o_complete && e_complete
        i_blocked = false
        o_blocked = false
        e_blocked = false

        unless i_complete
          begin
            bytes_written = i.write_nonblock(i_data)
            if bytes_written == i_data.length
              i.close
              i_complete = true
            else
              i_data = i_data[bytes_written .. -1]
            end
          rescue Errno::EWOULDBLOCK, Errno::EAGAIN, Errno::EINTR
            i_blocked = true
          end
        end

        unless o_complete
          begin
            oe_data << o.read_nonblock(CAPTURE_BUFFER_SIZE)
          rescue Errno::EWOULDBLOCK, Errno::EAGAIN
            o_blocked = true
          rescue EOFError
            raise unless i_complete
            o.close
            o_complete = true
          end
        end

        unless e_complete
          begin
            oe_data << e.read_nonblock(CAPTURE_BUFFER_SIZE)
          rescue Errno::EWOULDBLOCK, Errno::EAGAIN
            e_blocked = true
          rescue EOFError
            raise unless i_complete
            e.close
            e_complete = true
          end
        end

        if i_blocked && o_blocked && e_blocked
          IO.select([o, e], [i], [o,e,i])
        end
      end
      return [oe_data, t.value]
    end
  end
  module_function :capture2e

  CAPTURE_BUFFER_SIZE = 65536

  # Open3.pipeline_rw starts a list of commands as a pipeline with pipes
  # which connects stdin of the first command and stdout of the last command.
  #
  #   Open3.pipeline_rw(cmd1, cmd2, ...) {|first_stdin, last_stdout, wait_threads|
  #     ...
  #   }
  #
  #   first_stdin, last_stdout, wait_threads = Open3.pipeline_rw(cmd1, cmd2, ...)
  #   ...
  #   first_stdin.close
  #   last_stdout.close
  #
  # Each cmd is a string or an array.
  # If it is an array, the first element is the command name, and the remaining
  # elements are arguments passed (without parsing) to the command.
  #
  # Example:
  #
  #   Open3.pipeline_rw(["tr", "-dc", "A-Za-z"], ["wc", "-c"]) {|i,o,ts|
  #     i.puts "All persons more than a mile high to leave the court."
  #     i.close
  #     p o.gets #=> "42\n"
  #   }
  #
  #   Open3.pipeline_rw("sort", "cat -n") {|stdin, stdout, wait_thrs|
  #     stdin.puts "foo"
  #     stdin.puts "bar"
  #     stdin.puts "baz"
  #     stdin.close     # send EOF to sort.
  #     p stdout.read   #=> "     1\tbar\n     2\tbaz\n     3\tfoo\n"
  #   }
  def pipeline_rw(*cmds, &block)
    raise NotImplementedError
  end
  module_function :pipeline_rw

  # Open3.pipeline_r starts a list of commands as a pipeline with a pipe
  # which connects stdout of the last command.
  #
  #   Open3.pipeline_r(cmd1, cmd2, ...) {|last_stdout, wait_threads|
  #     ...
  #   }
  #
  #   last_stdout, wait_threads = Open3.pipeline_r(cmd1, cmd2, ...)
  #   ...
  #   last_stdout.close
  #
  # Each cmd is a string or an array.
  # If it is an array, the first element is the command name, and the remaining
  # elements are arguments passed (without parsing) to the command.
  #
  # Example:
  #
  #   Open3.pipeline_r("zcat /var/log/apache2/access.log.*.gz",
  #                    [{"LANG"=>"C"}, "grep", "GET /favicon.ico"],
  #                    "logresolve") {|o, ts|
  #     o.each_line {|line|
  #       ...
  #     }
  #   }
  #
  #   Open3.pipeline_r("yes", "head -10") {|o, ts|
  #     p o.read      #=> "y\ny\ny\ny\ny\ny\ny\ny\ny\ny\n"
  #     p ts[0].value #=> #<Process::Status: pid 24910 SIGPIPE (signal 13)>
  #     p ts[1].value #=> #<Process::Status: pid 24913 exit 0>
  #   }
  #
  def pipeline_r(*cmds, &block)
    raise NotImplementedError
  end
  module_function :pipeline_r

  # Open3.pipeline_w starts a list of commands as a pipeline with a pipe
  # which connects stdin of the first command.
  #
  #   Open3.pipeline_w(cmd1, cmd2, ...) {|first_stdin, wait_threads|
  #     ...
  #   }
  #
  #   first_stdin, wait_threads = Open3.pipeline_w(cmd1, cmd2, ...)
  #   ...
  #   first_stdin.close
  #
  # Each cmd is a string or an array.
  # If it is an array, the first element is the command name, and the remaining
  # elements are arguments passed (without parsing) to the command.
  #
  # Example:
  #
  #   Open3.pipeline_w("bzip2 -c", :out=>"/tmp/hello.bz2") {|i, ts|
  #     i.puts "hello"
  #   }
  #
  def pipeline_w(*cmds, &block)
    raise NotImplementedError
  end
  module_function :pipeline_w

  # Open3.pipeline_start starts a list of commands as a pipeline.
  # No pipe made for stdin of the first command and
  # stdout of the last command.
  #
  #   Open3.pipeline_start(cmd1, cmd2, ...) {|wait_threads|
  #     ...
  #   }
  #
  #   wait_threads = Open3.pipeline_start(cmd1, cmd2, ...)
  #   ...
  #
  # Each cmd is a string or an array.
  # If it is an array, the first element is the command name, and the remaining
  # elements are arguments passed (without parsing) to the command.
  #
  # Example:
  #
  #   # run xeyes in 10 seconds.
  #   Open3.pipeline_start("xeyes") {|ts|
  #     sleep 10
  #     t = ts[0]
  #     Process.kill("TERM", t.pid)
  #     p t.value #=> #<Process::Status: pid 911 SIGTERM (signal 15)>
  #   }
  #
  #   # convert pdf to ps and send it to a printer.
  #   # collect error message of pdftops and lpr.
  #   pdf_file = "paper.pdf"
  #   printer = "printer-name"
  #   err_r, err_w = IO.pipe
  #   Open3.pipeline_start(["pdftops", pdf_file, "-"],
  #                        ["lpr", "-P#{printer}"],
  #                        :err=>err_w) {|ts|
  #     err_w.close
  #     p err_r.read # error messages of pdftops and lpr.
  #   }
  #
  def pipeline_start(*cmds, &block)
    raise NotImplementedError
  end
  module_function :pipeline_start

  # Open3.pipeline starts a list of commands as a pipeline.
  # It waits the finish of the commands.
  # No pipe made for stdin of the first command and
  # stdout of the last command.
  #
  #   status_list = Open3.pipeline(cmd1, cmd2, ...)
  #
  # Each cmd is a string or an array.
  # If it is an array, the first element is the command name, and the remaining
  # elements are arguments passed (without parsing) to the command.
  #
  # Example:
  #
  #   fname = "/usr/share/man/man1/ruby.1.gz"
  #   p Open3.pipeline(["zcat", fname], "nroff -man", "less")
  #   #=> [#<Process::Status: pid 11817 exit 0>,
  #   #    #<Process::Status: pid 11820 exit 0>,
  #   #    #<Process::Status: pid 11828 exit 0>]
  #
  #   fname = "/usr/share/man/man1/ls.1.gz"
  #   Open3.pipeline(["zcat", fname], "nroff -man", "colcrt")
  #
  #   # convert PDF to PS and send to a printer by lpr
  #   pdf_file = "paper.pdf"
  #   printer = "printer-name"
  #   Open3.pipeline(["pdftops", pdf_file, "-"],
  #                  ["lpr", "-P#{printer}"])
  #
  #   # count lines
  #   Open3.pipeline("sort", "uniq -c", :in=>"names.txt", :out=>"count")
  #
  #   # cyclic pipeline
  #   r,w = IO.pipe
  #   w.print "ibase=14\n10\n"
  #   Open3.pipeline("bc", "tee /dev/tty", :in=>r, :out=>w)
  #   #=> 14
  #   #   18
  #   #   22
  #   #   30
  #   #   42
  #   #   58
  #   #   78
  #   #   106
  #   #   202
  #
  def pipeline(*cmds)
    raise NotImplementedError
  end
  module_function :pipeline
end
