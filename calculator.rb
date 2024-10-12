#!/usr/bin/env ruby -rdebug
<<-DOC
Implement a basic calculator to evaluate a simple equation string.

The equation string may contain open ( and closing parentheses ), the plus + or minus sign -, non-negative integers and empty spaces.

The equation string contains only non-negative integers, +, -, *, / operators , open ( and closing parentheses ) and empty spaces. The integer division should truncate toward zero.

You may assume that the given equation is always valid. All intermediate results will be in the range of [-2147483648, 2147483647].

Some examples:
"1 + 1" = 2
" 6-4 / 2 " = 4
"2*(5+5*2)/3+(6/2+8)" = 21
"(2+6* 3+5- (3*14/7+2)*5)+3"=-12
DOC

require 'pry';

class Number

    attr_reader :val

    def initialize(num)
        @val = num.to_i
        @num_digits = 1
    end

    def add_digit(num)
        @val = @val + (num.to_i * (10 ** @num_digits))
        @num_digits += 1
    end

    def make_negative
        @val = @val * -1
    end

    def /(other_number)
        @val = @val.to_f / other_number.val
    end

    def *(other_number)
        @val = @val.to_f * other_number.val
    end

    def +(other_number)
        @val = @val + other_number.val
    end

    def -(other_number)
        @val = @val - other_number.val
    end
end

class Calculator
    def initialize(equation)
        equation = "(" + equation + ")"
        @parser = Parser.new( equation )

        solve_parser(@parser)

        raise StandardError.new("Something went wrong") unless @parser.parsed_eq_lst.length == 1

        puts "Final value is #{@parser.parsed_eq_lst[0].val}"        
    end

    def solve_parser(parser)
        calculate_nested_parsers(parser)

        calculate_div_mul(parser)

        calculate_sums(parser)
    end

    def calculate_sums(parser)
        parser ||= @parser

        while parser.parsed_eq_lst.length >= 3
            left_num = parser.parsed_eq_lst[0]
            opr = parser.parsed_eq_lst[1]
            right_num = parser.parsed_eq_lst[2]

            left_num.public_send(opr, right_num)

            2.times { parser.parsed_eq_lst.delete_at(1) }
        end
    end

    def calculate_nested_parsers(parser)
        while parser.idx_of_parsers.length > 0 do
            sub_parser_idx = parser.idx_of_parsers.last

            sub_parser = parser.parsed_eq_lst[sub_parser_idx]
            
            solve_parser(sub_parser)

            parser.parsed_eq_lst[sub_parser_idx] = sub_parser.parsed_eq_lst[0]

            parser.idx_of_parsers.pop
        end
    end

    def calculate_div_mul(parser)

        offset = 0
        
        while parser.idx_of_mul_div_ops.length > 0 do
            opr_idx = parser.idx_of_mul_div_ops.last - offset

            if is_operator? parser.parsed_eq_lst[opr_idx]
                evaluate_equation(opr_idx, parser)
                2.times { parser.parsed_eq_lst.delete_at(opr_idx) }
                offset += 2
                parser.idx_of_mul_div_ops.pop
            else    
                raise StandardError.new("Error while offseting #{parser.parsed_eq_lst[opr_idx]} is not an operation")
            end
        end
    end

    def evaluate_equation(opr_idx, parser)
        opr = parser.parsed_eq_lst[opr_idx]
        left_num = parser.parsed_eq_lst[opr_idx - 1]
        right_num = parser.parsed_eq_lst[opr_idx + 1]
        
        if is_operator?(opr) && left_num.is_a?(Number) && right_num.is_a?(Number)
            left_num.public_send(opr, right_num)
        else
            raise StandardError.new("Error calculating #{left_num} #{opr} #{right_num}")
        end
    end

    private

    #add module for shared code
    def is_operator?(curr_char)
        ["+", "-", "*", "/"].include? curr_char
    end
end

class Parser

    attr_reader :eq
    attr_reader :parsed_eq_lst
    attr_reader :idx_of_mul_div_ops
    attr_reader :idx_of_parsers
    attr_reader :closing_bracket_found
    attr_reader :opening_bracket_found
    attr_reader :opening_to_closing_bracket_len

    def initialize(eq)
        raise StandardError.new("Expression needs closing bracket \')\'") unless eq[-1] == ")"
        
        @eq = eq

        @closing_bracket_found = false
        @opening_bracket_found = false

        @parsed_eq_lst = []
        @idx_of_mul_div_ops = []
        @idx_of_parsers = []

        parse_equation

        raise StandardError.new("Expression needs opening bracket \'(\'") unless @opening_bracket_found
    end

    def parse_equation
        if @eq == " " or @eq == nil
            return 0
        end

        idx = @eq.length - 1
        while idx >= 0 do
            if is_bracket? @eq[idx]
                if @eq[idx] == ")" && !closing_bracket_found
                    @closing_bracket_found = true
                elsif @eq[idx] == ")" && closing_bracket_found
                    new_parser = Parser.new(@eq.slice(0, idx + 1))
                    idx = idx - new_parser.opening_to_closing_bracket_len + 1
                    @parsed_eq_lst = [new_parser] + @parsed_eq_lst
                    @idx_of_parsers.append(@parsed_eq_lst.length)

                elsif @eq[idx] == "("
                    @opening_bracket_found = true
                    @opening_to_closing_bracket_len = @eq.length - idx
                    @eq = @eq.slice!(idx, @eq.length)
                    
                    idx = 0
                end
            else 
                parse_char(@eq[idx])
            end

            idx -= 1
        end

        validate_first_eq

        reindex_mul_div_ops

        reindex_parsers
    end

    private

    def reindex_mul_div_ops
        @idx_of_mul_div_ops.length.times do |idx|
            @idx_of_mul_div_ops[idx] = @parsed_eq_lst.length - @idx_of_mul_div_ops[idx]
        end
    end
    
    def reindex_parsers
        @idx_of_parsers.length.times do |idx|
            @idx_of_parsers[idx] = @parsed_eq_lst.length - @idx_of_parsers[idx]
        end
    end

    def validate_first_eq
        if is_operator? @parsed_eq_lst.first
            if @parsed_eq_lst.first == "-"
                if @parsed_eq_lst[1].is_a? Number
                    @parsed_eq_lst[1].make_negative
                    @parsed_eq_lst.slice!(0)
                else
                    raise StandardError.new("Something is bizarre")
                end
            elsif @parsed_eq_lst.first == "+"
                if @parsed_eq_lst[1].is_a? Number
                    @parsed_eq_lst.slice!(0)
                else
                    raise StandardError.new("Something is bizarre")
                end
            else
                raise StandardError.new("Can't have #{@parsed_eq_lst.first} without a complete operation")
            end
        end
    end

    def parse_char(curr_char)

        last_char = @parsed_eq_lst.first
        if is_digit?(curr_char)
            if last_char.is_a? Number
                last_char.add_digit(curr_char)
            elsif last_char.is_a? Parser
                @parsed_eq_lst = [Number.new(curr_char), "*"] + @parsed_eq_lst
            else
                @parsed_eq_lst = [Number.new(curr_char)] + @parsed_eq_lst
            end
        elsif is_operator?(curr_char)
            if @parsed_eq_lst.length == 0
                raise StandardError.new("Can't have #{curr_char} without something to evaluate")
            end

            if is_operator? last_char
                operator_collision_resolver(last_char, curr_char)
            else
                @parsed_eq_lst = [curr_char] + @parsed_eq_lst
            end

            if curr_char == "/" || curr_char == "*"
                @idx_of_mul_div_ops.append(@parsed_eq_lst.length)
            end
        else
            puts "Found a blank!"
        end

        puts "current state is #{@parsed_eq_lst}"
    end

    def operator_collision_resolver(last_char, curr_char)
        if last_char == "-" && curr_char == "-"
            @parsed_eq_lst[0] = "+"
        elsif last_char == "+" && curr_char == "-"
            @parsed_eq_lst[0] = "-"
        elsif last_char == "-" && curr_char == "+"
            @parsed_eq_lst[0] = "-"
        elsif last_char == "+" && curr_char == "+"
            @parsed_eq_lst[0] = "-"
        elsif last_char == "-" && curr_char == "/"
            if @parsed_eq_lst[1].is_a? Number
                @parsed_eq_lst[1].make_negative
                @parsed_eq_lst[0] = "/"
            else
                raise StandardError.new("Something is bizarre")
            end
        elsif last_char == "+" && curr_char == "/"
            if @parsed_eq_lst[1].is_a? Number
                @parsed_eq_lst[0] = "/"
            else
                raise StandardError.new("Something is bizarre")
            end
        elsif last_char == "-" && curr_char == "*"
            if @parsed_eq_lst[1].is_a? Number
                @parsed_eq_lst[1].make_negative
                @parsed_eq_lst[0] = "*"
            else
                raise StandardError.new("Something is bizarre")
            end
        elsif last_char == "+" && curr_char == "*"
            if @parsed_eq_lst[1].is_a? Number
                @parsed_eq_lst[0] = "*"
            else
                raise StandardError.new("Something is bizarre")
            end
        else
            raise StandardError.new("Can't have #{curr_char} and #{last_char} in a row without a number somewhere")
        end
    end

    def is_digit?(curr_char)
        ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"].include? curr_char
    end

    def is_operator?(curr_char)
        ["+", "-", "*", "/"].include? curr_char
    end

    def is_bracket?(curr_char)
        ["(", ")"].include? curr_char
    end
end

# not going to begin with removing empty spaces to make life more difficult
def run
    equation1 = "125*24 - 3 /2 + 7"
    equation2 = "   -125 + -1/2*3   *+3/ -54"
    equation3 = "5 * 5/---1"
    equation4 = "-"
    equation5 = "(5+(1/2+5) + 4/3 + (3) + (1*4/-2))"
    equation6 = "-)5+(1/2+5()"
    equation7 = "(5/(3(5/2) + 3) / 8)"
    equation8 = "(5+(3/2))"
    
    # parser = Parser.new(equation7)
    # parser
    calc = Calculator.new(equation7)
    calc
end
#equation2 = " 1  + 234"


