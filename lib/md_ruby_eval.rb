require 'pry'
require 'pp'
require 'optparse'

class MDRubyEval

  def initialize(input_path, output_path, environment, indentation, line_length, verbose)
    @input_path  = File.expand_path input_path
    @output_path = output_path
    @environment = environment
    @output      = ''
    @indentation = indentation
    @line_length = line_length
    @verbose     = verbose

    @last_id   = 1
    @known_ids = Hash.new { |h, k| h[k] = format('%06x', @last_id += 1) }
    @too_long  = []

    process_file input_path
  end

  def evaluate(code, line)
    puts code if @verbose
    start = Time.now
    eval(code, @environment, @input_path, line)
  ensure
    took   = Time.now - start
    output = format "\e[1m== %5.2f seconds   %s:%d\e[22m", took, @input_path, line
    puts output if @verbose
    @too_long << [took, code + output] if took > 0.1
  end

  def process_ruby(part, start_line)
    lines  = part.lines
    chunks = []
    line   = ''

    while !lines.empty?
      line += lines.shift
      if Pry::Code.complete_expression? line
        chunks << line
        line = ''
      end
    end

    raise unless line.empty?

    chunk_lines = chunks.map { |chunk| [chunk, [chunk.split($/).size, 1].max] }
    line_count  = start_line
    output      = ''
    chunk_lines.each do |chunk, lines|
      result = evaluate(chunk, line_count)
      if chunk.strip.empty? || chunk.lines.last.include?('#')
        output << (chunk.end_with?("#\n") ? chunk[0..-3] + "\n" : chunk)
      else
        pre_lines = chunk.lines.to_a
        last_line = pre_lines.pop
        output << pre_lines.join

        if last_line =~ /\#$/
          output << last_line.gsub(/\#$/, '')
        else
          inspected_result = normalize result.inspect
          if last_line.size < @indentation && inspected_result.size < @indentation
            output << "%-#{@indentation}s %s" % [last_line.chomp, "# => #{inspected_result}\n"]
          else
            PP.pp result, (buf = ''), @line_length
            buf           = normalize buf
            inspect_lines = buf.lines
            output << last_line << "# => #{inspect_lines[0]}" << inspect_lines[1..-1].map { |l| format '#    %s', l }.join
          end
        end
      end
      line_count += lines
    end
    output
  end


  def normalize(output)
    basename = File.basename(@input_path)
    output.
        gsub(/(#<[\w:_]+0x)([0-9a-f]{16})/) { $1 + @known_ids[$2] }.
        gsub(/#{@input_path}/, basename)
  end

  def process_file(input_path)
    puts "evaluating: #{input_path}"

    input = File.read(input_path)

    if File.extname(input_path) == '.rb'
      @output << process_ruby(input, 1)
    else
      parts = input.split(/^(```\w*\n)/)

      code_block = nil
      line_count = 1

      parts.each do |part|
        if part =~ /^```(\w+)$/
          code_block = $1
          @output << part
          line_count += 1
          next
        end

        if part =~ /^```$/
          code_block = nil
          @output << part
          line_count += 1
          next
        end

        if code_block == 'ruby'
          @output << process_ruby(part, line_count)
          line_count += part.lines.size
          next
        end

        @output << part
        line_count += part.lines.size
      end

      to_print = @too_long.sort_by { |took, _| -took }[0..10]
      if to_print.size > 0
        puts "#{to_print.size} longest evaluations:"
        to_print.each { |_, out| puts out }
      end
    end

    puts "writing: #{@output_path}"
    File.write(@output_path, @output)
  rescue => ex
    puts "#{ex} (#{ex.class})\n#{ex.backtrace * "\n"}"
  end
end
