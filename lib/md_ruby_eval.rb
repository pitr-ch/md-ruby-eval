require 'pry'
require 'pp'
require 'optparse'

class MDRubyEval

  def initialize(input_path, output_path, environment, indentation, line_length)
    @input_path  = input_path
    @output_path = output_path
    @environment = environment
    @output      = ''
    @indentation = indentation
    @line_length = line_length

    process_file input_path
  end

  def evaluate(code, line)
    eval(code, @environment, @input_path, line)
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
      if chunk.strip.empty? || chunk.include?('#')
        output << (chunk.end_with?("#\n") ? chunk[0..-3]+"\n" : chunk)
      else
        pre_lines = chunk.lines.to_a
        last_line = pre_lines.pop
        output << pre_lines.join

        if last_line =~ /\#$/
          output << last_line.gsub(/\#$/, '')
        else
          if last_line.size < @indentation && result.inspect.size < @indentation
            output << "%-#{@indentation}s %s" % [last_line.chomp, "# => #{result.inspect}\n"]
          else
            PP.pp result, (buf = ''), @line_length
            inspect_lines = buf.lines
            output << last_line << "# => #{inspect_lines[0]}" << inspect_lines[1..-1].map { |l| format '#    %s', l }.join
          end
        end
      end
      line_count += lines
    end
    output
  end

  def process_file(input_path)
    puts "evaluating: #{input_path}"

    input      = File.read(input_path)
    parts      = input.split(/^(```\w*\n)/)

    # pp parts.map(&:lines)

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

    puts "writing: #{@output_path}"
    File.write(@output_path, @output)
  rescue => ex
    puts "#{ex} (#{ex.class})\n#{ex.backtrace * "\n"}"

  end
end
