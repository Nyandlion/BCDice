# -*- coding: utf-8 -*-
# frozen_string_literal: true

require 'diceBot/DiceBot'
require 'utils/ArithmeticEvaluator'

class DoubleCross < DiceBot
  require 'diceBot/DoubleCross/DX'

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

  def rollDiceCommand(command)
    if (dx = parse(command))
      return dx.execute(self)
    end

    if command == 'ET'
      return get_emotion_table
    end

    return nil
  end

  private

  # 構文解析する
  # @param [String] command コマンド文字列
  # @return [DX, nil]
  def parse(command)
    case command
    when DX_OD_TOOL_RE
      return parse_dx_od(Regexp.last_match)
    when DX_SHIPPU_DOTO_RE
      return parse_dx_shippu_doto(Regexp.last_match)
    end

    return nil
  end

  # OD Tool式の成功判定コマンドの正規表現マッチ情報からノードを作る
  # @param [MatchData] m 正規表現のマッチ情報
  # @return [DX]
  def parse_dx_od(m)
    num = m[1].to_i
    modifier = m[2] ? ArithmeticEvaluator.new.eval(m[2]) : 0
    critical_value = m[4] ? m[4].to_i : 10

    # @type [Integer, nil]
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

    # @type [Integer, nil]
    target_value = m[5] && m[5].to_i

    return DX.new(num, critical_value, modifier, target_value)
  end

  # ** 感情表
  def get_emotion_table()
    output = nil

    pos_dice, pos_table = dx_feel_positive_table
    neg_dice, neg_table = dx_feel_negative_table
    dice_now, = roll(1, 2)

    if (pos_table != '1') && (neg_table != '1')
      if dice_now < 2
        pos_table = "○" + pos_table
      else
        neg_table = "○" + neg_table
      end
      output = "感情表(#{pos_dice}-#{neg_dice}) ＞ #{pos_table} - #{neg_table}"
    end

    return output
  end

  # ** 感情表（ポジティブ）
  def dx_feel_positive_table
    table = [
      [0, '傾倒(けいとう)'],
      [5, '好奇心(こうきしん)'],
      [10, '憧憬(どうけい)'],
      [15, '尊敬(そんけい)'],
      [20, '連帯感(れんたいかん)'],
      [25, '慈愛(じあい)'],
      [30, '感服(かんぷく)'],
      [35, '純愛(じゅんあい)'],
      [40, '友情(ゆうじょう)'],
      [45, '慕情(ぼじょう)'],
      [50, '同情(どうじょう)'],
      [55, '遺志(いし)'],
      [60, '庇護(ひご)'],
      [65, '幸福感(こうふくかん)'],
      [70, '信頼(しんらい)'],
      [75, '執着(しゅうちゃく)'],
      [80, '親近感(しんきんかん)'],
      [85, '誠意(せいい)'],
      [90, '好意(こうい)'],
      [95, '有為(ゆうい)'],
      [100, '尽力(じんりょく)'],
      [101, '懐旧(かいきゅう)'],
      [102, '任意(にんい)'],
    ]

    return dx_feel_table(table)
  end

  # ** 感情表（ネガティブ）
  def dx_feel_negative_table
    table = [
      [0, '侮蔑(ぶべつ)'],
      [5, '食傷(しょくしょう)'],
      [10, '脅威(きょうい)'],
      [15, '嫉妬(しっと)'],
      [20, '悔悟(かいご)'],
      [25, '恐怖(きょうふ)'],
      [30, '不安(ふあん)'],
      [35, '劣等感(れっとうかん)'],
      [40, '疎外感(そがいかん)'],
      [45, '恥辱(ちじょく)'],
      [50, '憐憫(れんびん)'],
      [55, '偏愛(へんあい)'],
      [60, '憎悪(ぞうお)'],
      [65, '隔意(かくい)'],
      [70, '嫌悪(けんお)'],
      [75, '猜疑心(さいぎしん)'],
      [80, '厭気(いやけ)'],
      [85, '不信感(ふしんかん)'],
      [90, '不快感(ふかいかん)'],
      [95, '憤懣(ふんまん)'],
      [100, '敵愾心(てきがいしん)'],
      [101, '無関心(むかんしん)'],
      [102, '任意(にんい)'],
    ]

    return dx_feel_table(table)
  end

  def dx_feel_table(table)
    dice_now, = roll(1, 100)
    output = get_table_by_number(dice_now, table)

    return dice_now, output
  end
end
