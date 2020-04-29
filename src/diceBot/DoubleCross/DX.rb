# -*- coding: utf-8 -*-
# frozen_string_literal: true

require 'utils/modifier_formatter'

class DoubleCross
  # 成功判定コマンドのノード
  class DX
    include ModifierFormatter

    # ノードを初期化する
    # @param [Integer] num ダイス数
    # @param [Integer] critical_value クリティカル値
    # @param [Integer] modifier 修正値
    # @param [Integer] target_value 目標値
    def initialize(num, critical_value, modifier, target_value)
      @num = num
      @critical_value = critical_value
      @modifier = modifier
      @target_value = target_value

      @modifier_str = format_modifier(@modifier)
      @expression = node_expression()
    end

    # 成功判定を行う
    # @param [DiceBot] bot ダイスボット
    # @return [String] 判定結果
    def execute(bot)
      if @critical_value < 2
        return "(#{@expression}) ＞ クリティカル値が低すぎます。2以上を指定してください。"
      end

      if @num < 1
        return "(#{@expression}) ＞ 自動失敗"
      end

      # 出目のグループの配列
      value_groups = []
      # 次にダイスロールを行う際のダイス数
      num_of_dice = @num
      # 回転数
      loop_count = 0

      while num_of_dice > 0 && bot.should_reroll?(loop_count)
        values = Array.new(num_of_dice) { bot.roll(1, 10)[0] }

        value_group = ValueGroup.new(values, @critical_value)
        value_groups.push(value_group)

        # 次回はクリティカル発生数と等しい個数のダイスを振る
        # [3rd ルールブック1 p. 185]
        num_of_dice = value_group.num_of_critical_occurrences

        loop_count += 1
      end

      return result_str(value_groups, loop_count)
    end

    private

    # 数式表記を返す
    # @return [String]
    def node_expression
      lhs = "#{@num}DX#{@critical_value}#{@modifier_str}"

      return @target_value ? "#{lhs}>=#{@target_value}" : lhs
    end

    # 判定結果の文字列を返す
    # @param [Array<ValueGroup>] value_groups 出目のグループの配列
    # @param [Integer] loop_count 回転数
    # @return [String]
    def result_str(value_groups, loop_count)
      fumble = value_groups[0].values.all? { |value| value == 1 }
      # TODO: Ruby 2.4以降では Array#sum が使える
      sum = value_groups.map(&:max).reduce(0, &:+)
      achieved_value = fumble ? 0 : (sum + @modifier)

      long_str = result_str_long(value_groups, achieved_value, fumble)

      if long_str.length > $SEND_STR_MAX
        return result_str_short(loop_count, achieved_value, fumble)
      end

      return long_str
    end

    # ダイスロール結果の長い文字列表記を返す
    # @param [Array<ValueGroup>] value_groups 出目のグループの配列
    # @param [Integer] achieved_value 達成値
    # @param [Boolean] fumble ファンブルしたか
    # @return [String]
    def result_str_long(value_groups, achieved_value, fumble)
      parts = [
        "(#{@expression})",
        "#{value_groups.join('+')}#{@modifier_str}",
        achieved_value_with_if_fumble(achieved_value, fumble),
        compare_result(achieved_value, fumble)
      ]

      return parts.compact.join(' ＞ ')
    end

    # ダイスロール結果の短い文字列表記を返す
    # @param [Integer] loop_count 回転数
    # @param [Integer] achieved_value 達成値
    # @param [Boolean] fumble ファンブルしたか
    # @return [String]
    def result_str_short(loop_count, achieved_value, fumble)
      parts = [
        "(#{@expression})",
        '...',
        "回転数#{loop_count}",
        achieved_value_with_if_fumble(achieved_value, fumble),
        compare_result(achieved_value, fumble)
      ]

      return parts.compact.join(' ＞ ')
    end

    # ファンブルかどうかを含む達成値の表記を返す
    # @param [Integer] achieved_value 達成値
    # @param [Boolean] fumble ファンブルしたか
    # @return [String]
    def achieved_value_with_if_fumble(achieved_value, fumble)
      fumble ? "#{achieved_value} (ファンブル)" : achieved_value.to_s
    end

    # 達成値と目標値を比較した結果を返す
    # @param [Integer] achieved_value 達成値
    # @param [Boolean] fumble ファンブルしたか
    # @return [String, nil]
    def compare_result(achieved_value, fumble)
      return nil unless @target_value

      # ファンブル時は自動失敗
      # [3rd ルールブック1 pp. 186-187]
      return '失敗' if fumble

      # 達成値が目標値以上ならば行為判定成功
      # [3rd ルールブック1 p. 187]
      return achieved_value >= @target_value ? '成功' : '失敗'
    end
  end

  # 出目のグループを表すクラス
  class ValueGroup
    # 出目の配列
    # @return [Array<Integer>]
    attr_reader :values
    # クリティカル値
    # @return [Integer]
    attr_reader :critical_value

    # 出目のグループを初期化する
    # @param [Array<Integer>] values 出目の配列
    # @param [Integer] critical_value クリティカル値
    def initialize(values, critical_value)
      @values = values.sort
      @critical_value = critical_value
    end

    # 出目のグループの文字列表記を返す
    # @return [String]
    def to_s
      "#{max}[#{@values.join(',')}]"
    end

    # 出目のグループ中の最大値を返す
    # @return [Integer]
    #
    # クリティカル値以上の出目が含まれていた場合は10を返す。
    # [3rd ルールブック1 pp. 185-186]
    def max
      @values.any? { |value| critical?(value) } ? 10 : @values.max
    end

    # クリティカルの発生数を返す
    # @return [Integer]
    def num_of_critical_occurrences
      @values.
        select { |value| critical?(value) }.
        length
    end

    private

    # クリティカルが発生したかを返す
    # @param [Integer] value 出目
    # @return [Boolean]
    #
    # クリティカル値以上の値が出た場合、クリティカルとする。
    # [3rd ルールブック1 pp. 185-186]
    def critical?(value)
      value >= @critical_value
    end
  end
end
