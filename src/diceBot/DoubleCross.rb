# -*- coding: utf-8 -*-
# frozen_string_literal: true

require 'diceBot/DiceBot'
require 'utils/ArithmeticEvaluator'

class DoubleCross < DiceBot
  require 'diceBot/DoubleCross/DX'
  require 'diceBot/DoubleCross/ET'

  # ゲームシステムの識別子
  ID = 'DoubleCross'

  # ゲームシステム名
  NAME = 'ダブルクロス2nd,3rd'

  # ゲームシステム名の読みがな
  SORT_KEY = 'たふるくろす2'

  # ダイスボットの使い方
  HELP_MESSAGE = <<INFO_MESSAGE_TEXT
・判定コマンド　(xDX+y@c or xDXc+y)
　"(個数)DX(修正)@(クリティカル値)"もしくは"(個数)DX(クリティカル値)(修正)"で指定します。
　修正値も付けられます。
　例）10dx　　　10dx+5@8(OD tool式)　　　5DX7+7-3(疾風怒濤式)

・各種表
　・感情表(ET)
　　ポジティブとネガティブの両方を振って、表になっている側に○を付けて表示します。もちろん任意で選ぶ部分は変更して構いません。

・D66ダイスあり
INFO_MESSAGE_TEXT

  setPrefixes(['\d+DX.*', 'ET'])

  # OD Tool式の成功判定コマンドの正規表現
  #
  # キャプチャ内容は以下のとおり:
  #
  # 1. ダイス数
  # 2. 修正値
  # 4. クリティカル値
  # 5. 達成値
  DX_OD_TOOL_RE = /\A(\d+)DX([-+]\d+([-+*]\d+)*)?@(\d+)(?:>=(\d+))?\z/io.freeze

  # 疾風怒濤式の成功判定コマンドの正規表現
  #
  # キャプチャ内容は以下のとおり:
  #
  # 1. ダイス数
  # 2. クリティカル値
  # 3. 修正値
  # 5. 達成値
  DX_SHIPPU_DOTO_RE = /\A(\d+)DX(\d+)?([-+]\d+([-+*]\d+)*)?(?:>=(\d+))?\z/io.freeze

  def check_nD10(total, _dice_total, dice_list, cmp_op, target)
    return '' unless cmp_op == :>=

    if dice_list.count(1) == dice_list.size
      " ＞ ファンブル"
    elsif total >= target
      " ＞ 成功"
    else
      " ＞ 失敗"
    end
  end

  # ダイスボット固有コマンドの処理を行う
  # @param [String] command コマンド
  # @return [String] ダイスボット固有コマンドの結果
  # @return [nil] 無効なコマンドだった場合
  def rollDiceCommand(command)
    node = parse(command)
    return nil unless node

    return node.execute(self)
  end

  private

  # 構文解析する
  # @param [String] command コマンド文字列
  # @return [ET, DX, nil]
  def parse(command)
    case command
    when 'ET'
      ET.new
    when DX_OD_TOOL_RE
      parse_dx_od(Regexp.last_match)
    when DX_SHIPPU_DOTO_RE
      parse_dx_shippu_doto(Regexp.last_match)
    end
  end

  # OD Tool式の成功判定コマンドの正規表現マッチ情報からノードを作る
  # @param [MatchData] m 正規表現のマッチ情報
  # @return [DX]
  def parse_dx_od(m)
    num = m[1].to_i
    modifier = m[2] ? ArithmeticEvaluator.new.eval(m[2]) : 0
    critical_value = m[4] ? m[4].to_i : 10

    target_value = m[5] && m[5].to_i

    return DX.new(num, critical_value, modifier, target_value)
  end

  # 疾風怒濤式の成功判定コマンドの正規表現マッチ情報からノードを作る
  # @param [MatchData] m 正規表現のマッチ情報
  # @return [DX]
  def parse_dx_shippu_doto(m)
    num = m[1].to_i
    critical_value = m[2] ? m[2].to_i : 10
    modifier = m[3] ? ArithmeticEvaluator.new.eval(m[3]) : 0

    target_value = m[5] && m[5].to_i

    return DX.new(num, critical_value, modifier, target_value)
  end
end
