require File.dirname(__FILE__) + '/../spec_helper'

describe Open3 do
  context "Open3.popen3" do
    it "should support block form" do
      Open3.popen3("echo", "test value") do |i,o,e,t|
        t.pid.should > 0
        o.read.strip.should == 'test value'
        e.read.strip.should == ''
        t.value.success?.should be_true
      end
    end

    it "should support non-block form" do
      i,o,e,t = Open3.popen3("echo", "test value")
      t[:pid].should > 0
      o.read.strip.should == 'test value'
      e.read.strip.should == ''
      i.close
      o.close
      e.close
      t.value.success?.should be_true
    end

    it "should expand its first argument" do
      Open3.popen3("echo $PATH") do |i,o,e,t|
        output = o.read.strip
        output.should_not == '$PATH'
        output.length.should > 0
        e.read.strip.should  == ''
        t.value.success?.should be_true
      end
    end

    it "should not expand its other arguments" do
      Open3.popen3("echo","$PATH","$PATH") do |i,o,e,t|
        o.read.strip.should == '$PATH $PATH'
        e.read.strip.should  == ''
        t.value.success?.should be_true
      end
    end

    it "should keep stdout and stderr seperate" do
      Open3.popen3("cat - && cat /dev/monkey") do |i,o,e,t|
        i.write 'test value'
        i.close
        o.read.strip.should == 'test value'
        e.read.strip.should include '/dev/monkey'
      end
    end
  end

  context "Open3.popen2" do
    it "should support block form" do
      Open3.popen2("echo", "test value") do |i,o,t|
        t.pid.should > 0
        o.read.strip.should == 'test value'
        t.value.success?.should be_true
      end
    end

    it "should support non-block form" do
      i,o,t = Open3.popen2("echo", "test value")
      t[:pid].should > 0
      o.read.strip.should == 'test value'
      i.close
      o.close
      t.value.success?.should be_true
    end

    it "should expand its first argument" do
      Open3.popen2("echo $PATH") do |i,o,t|
        output = o.read.strip
        output.should_not == '$PATH'
        output.length.should > 0
        t.value.success?.should be_true
      end
    end

    it "should not expand its other arguments" do
      Open3.popen2("echo","$PATH","$PATH") do |i,o,t|
        o.read.strip.should == '$PATH $PATH'
        t.value.success?.should be_true
      end
    end

    it "should keep stdout throw out stderr" do
      Open3.popen2("cat - && cat /dev/monkey") do |i,o,t|
        i.write 'test value'
        i.close
        o.read.strip.should == 'test value'
      end
    end
  end

  context "Open3.popen2e" do
    it "doesn't work yet" do
      pending "merged_read_stream not implemented"
    end
  end

  context "Open3.capture3" do
    it "should expand its first argument" do
      o,e,s = Open3.capture3("echo $PATH")
      o.strip.should_not == '$PATH'
      o.strip.length.should > 0
      e.should  == ''
      s.success?.should be_true
    end

    it "should not expand its other arguments" do
      o,e,s = Open3.capture3("echo","$PATH","$PATH")
      o.strip.should == '$PATH $PATH'
      e.should  == ''
      s.success?.should be_true
    end

    it "should keep stdout and stderr seperate" do
      o,e,s = Open3.capture3("cat - && cat /dev/monkey", :stdin_data => "test value")
      o.strip.should == 'test value'
      e.should include '/dev/monkey'
      s.success?.should be_false
    end
  end

  context "Open3.capture2" do
    it "should expand its first argument" do
      o,s = Open3.capture2("echo $PATH")
      o.strip.should_not == '$PATH'
      o.strip.length.should > 0
      s.success?.should be_true
    end

    it "should not expand its other arguments" do
      o,s = Open3.capture2("echo","$PATH","$PATH")
      o.strip.should == '$PATH $PATH'
      s.success?.should be_true
    end

    it "should keep stdout and throw out stderr" do
      o,s = Open3.capture2("cat - && cat /dev/monkey", :stdin_data => "test value")
      o.strip.should == 'test value'
      s.success?.should be_false
    end
  end

  context "Open3.capture2e" do
    it "should expand its first argument" do
      o,s = Open3.capture2e("echo $PATH")
      o.strip.should_not == '$PATH'
      o.strip.length.should > 0
      s.success?.should be_true
    end

    it "should not expand its other arguments" do
      o,s = Open3.capture2e("echo","$PATH","$PATH")
      o.strip.should == '$PATH $PATH'
      s.success?.should be_true
    end

    it "should combine stdout and stderr" do
      o,s = Open3.capture2e("cat - && cat /dev/monkey", :stdin_data => "test value")
      o.should include 'test value'
      o.should include '/dev/monkey'
      s.success?.should be_false
    end
  end

  context "Open3.pipeline_rw" do
    it "doesn't work yet" do
      pending "not implemented"
    end
  end

  context "Open3.pipeline_r" do
    it "doesn't work yet" do
      pending "not implemented"
    end
  end

  context "Open3.pipeline_w" do
    it "doesn't work yet" do
      pending "not implemented"
    end
  end

  context "Open3.pipeline_start" do
    it "doesn't work yet" do
      pending "not implemented"
    end
  end

  context "Open3.pipeline" do
    it "doesn't work yet" do
      pending "not implemented"
    end
  end
end
