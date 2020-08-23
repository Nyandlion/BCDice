# -*- coding: utf-8 -*-
# frozen_string_literal: true

require 'utils/range_table'

class DeadlineHeroes < DiceBot
  # ゲームシステムの識別子
  ID = 'DeadlineHeroes'

  # ゲームシステム名
  NAME = 'デッドラインヒーローズRPG'

  # ゲームシステム名の読みがな
  SORT_KEY = 'てつとらいんひいろおすRPG'

  # ダイスボットの使い方
  HELP_MESSAGE = <<INFO_MESSAGE_TEXT
・行為判定（DLHx）
　x：成功率
　例）DLH80
　クリティカル、ファンブルの自動的判定を行います。
　「DLH50+20-30」のように加減算記述も可能。
　成功率は上限100％、下限０％
・デスチャート(DCxY)
　x：チャートの種類。肉体：DCL、精神：DCS、環境：DCC
　Y=マイナス値
　例）DCL5：ライフが -5 の判定
　　　DCS3：サニティーが -3 の判定
　　　DCC0：クレジット 0 の判定
・ヒーローネームチャート（HNC）
・リアルネームチャート　日本（RNCJ）、海外（RNCO）
INFO_MESSAGE_TEXT

  setPrefixes([
    'DLH\\d+([\\+\\-]\\d+)*',
    'DC(L|S|C)\d+',
    'RNC[JO]',
    'HNC'
  ])

  def rollDiceCommand(command)
    case command
    when /^DLH/i
      return resolute_action(command)
    when /^DC\w/i
      return roll_death_chart(command)
    when /^HNC/i
      result = rollHeroNameTemplateChart()
      return "ヒーローネームチャート: 1D10[#{result[:dice]}] ＞ #{result[:result]}" unless result.nil?
    else
      return roll_tables(command, TABLES)
    end

    return nil
  end

  private

  def resolute_action(command)
    m = /^DLH(\d+([\+\-]\d+)*)$/.match(command)
    unless m
      return nil
    end

    success_rate = ArithmeticEvaluator.new().eval(m[1])

    roll_result, dice10, dice01 = roll_d100
    roll_result_text = format('%02d', roll_result)

    result = action_result(roll_result, dice10, dice01, success_rate)

    sequence = [
      "行為判定(成功率:#{success_rate}％)",
      "1D100[#{dice10},#{dice01}]=#{roll_result_text}",
      roll_result_text.to_s,
      result
    ]

    return sequence.join(" ＞ ")
  end

  SUCCESS_STR = "成功"
  FAILURE_STR = "失敗"
  CRITICAL_STR = (SUCCESS_STR + " ＞ クリティカル！ パワーの代償１／２").freeze
  FUMBLE_STR = (FAILURE_STR + " ＞ ファンブル！ パワーの代償２倍＆振り直し不可").freeze

  def action_result(total, tens, ones, success_rate)
    if total == 100 || success_rate <= 0
      FUMBLE_STR
    elsif total <= success_rate - 100
      CRITICAL_STR
    elsif tens == ones
      if total <= success_rate
        CRITICAL_STR
      else
        FUMBLE_STR
      end
    elsif total <= success_rate
      SUCCESS_STR
    else
      FAILURE_STR
    end
  end

  def roll_d100
    dice10, = roll(1, 10)
    dice10 = 0 if dice10 == 10
    dice01, = roll(1, 10)
    dice01 = 0 if dice01 == 10

    roll_result = dice10 * 10 + dice01
    roll_result = 100 if roll_result == 0

    return roll_result, dice10, dice01
  end

  class DeathChart
    def initialize(name, chart)
      @name = name
      @chart = chart.freeze

      if @chart.size != 11
        raise ArgumentError, "unexpected chart size #{name.inspect} (given #{@chart.size}, expected 11)"
      end
    end

    # @params bot [#roll]
    # @params minus_score [Integer]
    # @return [String]
    def roll(bot, minus_score)
      dice, = bot.roll(1, 10)
      key_number = dice + minus_score

      key_text, chosen = at(key_number)

      return "デスチャート（#{@name}）[マイナス値:#{minus_score} + 1D10(->#{dice}) = #{key_number}] ＞ #{key_text} ： #{chosen}"
    end

    private

    # key_numberの10から20がindexの0から10に対応する
    def at(key_number)
      if key_number < 10
        ["10以下", @chart.first]
      elsif key_number > 20
        ["20以上", @chart.last]
      else
        [key_number.to_s, @chart[key_number - 10]]
      end
    end
  end

  def roll_death_chart(command)
    m = /^DC([LSC])(\d+)$/i.match(command)
    unless m
      return m
    end

    chart = DEATH_CHARTS[m[1]]
    minus_score = m[2].to_i

    return chart.roll(self, minus_score)
  end

  DEATH_CHARTS = {
    'L' => DeathChart.new(
      '肉体',
      [
        "何も無し。キミは奇跡的に一命を取り留めた。闘いは続く。",
        "激痛が走る。以後、イベント終了時まで、全ての判定の成功率－10％。",
        "キミは［硬直］ポイント２点を得る。［硬直］ポイントを所持している間、キミは「属性：妨害」のパワーを使用することができない。各ラウンド終了時、キミは所持している［硬直］ポイントを１点減らしてもよい。",
        "渾身の一撃!!　キミは〈生存〉判定を行なう。失敗した場合、［死亡］する。",
        "キミは［気絶］ポイント２点を得る。［気絶］ポイントを所持している間、キミはあらゆるパワーを使用できず、自身のターンを得ることもできない。各ラウンド終了時、キミは所持している［気絶］ポイントを１点減らしてもよい。",
        "以後、イベント終了時まで、全ての判定の成功率－20％。",
        "記録的一撃!!　キミは〈生存〉－20％の判定を行なう。失敗した場合、［死亡］する。",
        "キミは［瀕死］ポイント２点を得る。［瀕死］ポイントを所持している間、キミはあらゆるパワーを使用できず、自身のターンを得ることもできない。各ラウンド終了時、キミは所持している［瀕死］ポイントを１点を失う。全ての［瀕死］ポイントを失う前に戦闘が終了しなかった場合、キミは［死亡］する。",
        "叙事詩的一撃!!　キミは〈生存〉－30％の判定を行なう。失敗した場合、［死亡］する。",
        "以後、イベント終了時まで、全ての判定の成功率－30％。",
        "神話的一撃!!　キミは宙を舞って三回転ほどした後、地面に叩きつけられる。見るも無惨な姿。肉体は原型を留めていない（キミは［死亡］した）。",
      ]
    ),
    'S' => DeathChart.new(
      '精神',
      [
        "何も無し。キミは歯を食いしばってストレスに耐えた。",
        "以後、イベント終了時まで、全ての判定の成功率－10％。",
        "キミは［恐怖］ポイント２点を得る。［恐怖］ポイントを所持している間、キミは「属性：攻撃」のパワーを使用できない。各ラウンド終了時、キミは所持している［恐怖］ポイントを１点減らしてもよい。",
        "とても傷ついた。キミは〈意志〉判定を行なう。失敗した場合、［絶望］してＮＰＣとなる。",
        "キミは［気絶］ポイント２点を得る。［気絶］ポイントを所持している間、キミはあらゆるパワーを使用できず、自身のターンを得ることもできない。各ラウンド終了時、キミは所持している［気絶］ポイントを１点減らしてもよい。",
        "以後、イベント終了時まで、全ての判定の成功率－20％。",
        "信じるものに裏切られたような痛み。キミは〈意志〉－20％の判定を行なう。失敗した場合、［絶望］してＮＰＣとなる。",
        "キミは［混乱］ポイント２点を得る。［混乱］ポイントを所持している間、キミは本来味方であったキャラクターに対して、可能な限り最大の被害を与える様、行動し続ける。各ラウンド終了時、キミは所持している［混乱］ポイントを１点減らしてもよい。",
        "あまりに残酷な現実。キミは〈意志〉－30％の判定を行なう。失敗した場合、［絶望］してＮＰＣとなる。",
        "以後、イベント終了時まで、全ての判定の成功率－30％。",
        "宇宙開闢の理に触れるも、それは人類の認識限界を超える何かであった。キミは［絶望］し、以後ＮＰＣとなる。",
      ]
    ),
    'C' => DeathChart.new(
      '環境',
      [
        "何も無し。キミは黒い噂を握りつぶした。",
        "以後、イベント終了時まで、全ての判定の成功率－10％。",
        "ピンチ！　以後、イベント終了時まで、キミは《支援》を使用できない。",
        "裏切り!!　キミは〈経済〉判定を行なう。失敗した場合、キミはヒーローとしての名声を失い、［汚名］を受ける。",
        "以後、シナリオ終了時まで、代償にクレジットを消費するパワーを使用できない。",
        "キミの悪評は大変なもののようだ。協力者からの支援が打ち切られる。以後、シナリオ終了時まで、全ての判定の成功率－20％。",
        "信頼の失墜!!　キミは〈経済〉－20％の判定を行なう。失敗した場合、キミはヒーローとしての名声を失い、［汚名］を受ける。",
        "以後、シナリオ終了時まで、【環境】系の技能のレベルがすべて０となる。",
        "捏造報道!!　身の覚えのない犯罪への荷担が、スクープとして報道される。キミは〈経済〉－30％の判定を行なう。失敗した場合、キミはヒーローとしての名声を失い、［汚名］を受ける。",
        "以後、イベント終了時まで、全ての判定の成功率－30％。",
        "キミの名は史上最悪の汚点として永遠に歴史に刻まれる。もはやキミを信じる仲間はなく、キミを助ける社会もない。キミは［汚名］を受けた。",
      ]
    )
  }.freeze

  class RealNameChart < RangeTable
    def initialize(name, columns, chart)
      items = chart.map { |l| mix_column(columns, l) }
      super(name, "1D100", items)
    end

    private

    def mix_column(columns, item)
      range, names = item
      if names.size == 1
        return range, names[0]
      end

      candidate = columns.zip(names).map { |l| "\n" + l.join(": ") }.join("")
      return range, candidate
    end
  end

  TABLES = {
    'RNCJ' => RealNameChart.new(
      'リアルネームチャート（日本）',
      ['姓', '名（男）', '名（女）'],
      [
        [ 1..6, ['アイカワ／相川、愛川', 'アキラ／晶、章', 'アン／杏']],
        [ 7..12, ['アマミヤ／雨宮', 'エイジ／映司、英治', 'イノリ／祈鈴、祈']],
        [13..18, ['イブキ／伊吹', 'カズキ／和希、一輝', 'エマ／英真、恵茉']],
        [19..24, ['オガミ／尾上', 'ギンガ／銀河', 'カノン／花音、観音']],
        [25..30, ['カイ／甲斐', 'ケンイチロウ／健一郎', 'サラ／沙羅']],
        [31..36, ['サカキ／榊、阪木', 'ゴウ／豪、剛', 'シズク／雫']],
        [37..42, ['シシド／宍戸', 'ジロー／次郎、治郎', 'チズル／千鶴、千尋']],
        [43..48, ['タチバナ／橘、立花', 'タケシ／猛、武', 'ナオミ／直美、尚美']],
        [49..54, ['ツブラヤ／円谷', 'ツバサ／翼', 'ハル／華、波留']],
        [55..60, ['ハヤカワ／早川', 'テツ／鉄、哲', 'ヒカル／光']],
        [61..66, ['ハラダ／原田', 'ヒデオ／英雄', 'ベニ／紅']],
        [67..72, ['フジカワ／藤川', 'マサムネ／正宗、政宗', 'マチ／真知、町']],
        [73..78, ['ホシ／星', 'ヤマト／大和', 'ミア／深空、美杏']],
        [79..84, ['ミゾグチ／溝口', 'リュウセイ／流星', 'ユリコ／由里子']],
        [85..90, ['ヤシダ／矢志田', 'レツ／烈、裂', 'ルイ／瑠衣、涙']],
        [91..96, ['ユウキ／結城', 'レン／連、錬', 'レナ／玲奈']],
        [97..100, ['名無し（何らかの理由で名前を持たない、もしくは失った）']],
      ]
    ),
    'RNCO' => RealNameChart.new(
      'リアルネームチャート（海外）',
      ['名（男）', '名（女）', '姓'],
      [
        [ 1..6, ['アルバス', 'アイリス', 'アレン']],
        [ 7..12, ['クリス', 'オリーブ', 'ウォーケン']],
        [13..18, ['サミュエル', 'カーラ', 'ウルフマン']],
        [19..24, ['シドニー', 'キルスティン', 'オルセン']],
        [25..30, ['スパイク', 'グウェン', 'カーター']],
        [31..36, ['ダミアン', 'サマンサ', 'キャラダイン']],
        [37..42, ['ディック', 'ジャスティナ', 'シーゲル']],
        [43..48, ['デンゼル', 'タバサ', 'ジョーンズ']],
        [49..54, ['ドン', 'ナディン', 'パーカー']],
        [55..60, ['ニコラス', 'ノエル', 'フリーマン']],
        [61..66, ['ネビル', 'ハーリーン', 'マーフィー']],
        [67..72, ['バリ', 'マルセラ', 'ミラー']],
        [73..78, ['ビリー', 'ラナ', 'ムーア']],
        [79..84, ['ブルース', 'リンジー', 'リーヴ']],
        [85..90, ['マーヴ', 'ロザリー', 'レイノルズ']],
        [91..96, ['ライアン', 'ワンダ', 'ワード']],
        [97..100, ['名無し（何らかの理由で名前を持たない、もしくは失った）']],
      ]
    )
  }.freeze

  def rollHeroNameTemplateChart()
    chart = HERO_NAME_TEMPLATES

    dice, = roll(1, 10)

    templateText = chart[dice][:text]
    return nil if templateText.nil?

    result = {:dice => dice, :result => templateText}
    return result if templateText == "任意"

    elements = chart[dice][:elements]

    resolvedElements = elements.map { |i| rollHeroNameBaseChart(i) }

    text = resolvedElements.map { |i| getHeroNameElementText(i) }.join(" ＋ ")
    resultText = resolvedElements.map { |i| i[:coreResult] }.join("").sub(/・{2,}/, "・").sub(/・$/, "")

    result[:result] += " ＞ ( #{text} ) ＞ 「#{resultText}」"

    return result
  end

  def getHeroNameElementText(info)
    result = ""
    result += (info[:chartName]).to_s if info.key?(:chartName)
    result += "(1D10[#{info[:dice]}]) ＞ " if info.key?(:dice)
    result += "［#{info[:innerChartName]}］ ＞ 1D10[#{info[:innerResult][:dice]}] ＞ " if info.key?(:innerChartName)
    result += "「#{info[:coreResult]}」"
  end

  def rollHeroNameBaseChart(chartName)
    defaultResult = {:result => chartName, :coreResult => chartName}

    chart = HERO_NAME_BASE_CHARTS[chartName]
    return defaultResult if chart.nil?

    dice, = roll(1, 10)
    return defaultResult unless chart.key?(dice)

    result = {:dice => dice, :result => chart[dice], :chartName => chartName}
    result[:coreResult] = result[:result]

    if result[:result] =~ /［(.+)］/
      innerResult = rollHeroNameElementChart(Regexp.last_match(1).to_s)
      result[:innerResult] = innerResult
      result[:innerChartName] = innerResult[:chartName]
      result[:coreResult] = innerResult[:name]
      result[:result] += " ＞ 1D10[#{innerResult[:dice]}] ＞ #{innerResult[:name]}（意味：#{innerResult[:mean]}）"
    end

    return result
  end

  def rollHeroNameElementChart(chartName)
    chart = HERO_NAME_ELEMENT_CHARTS[chartName.sub("/", "／")]
    return nil if chart.nil?

    dice, = roll(1, 10)
    return nil unless chart.key?(dice)

    name, mean, = chart[dice]

    return {:dice => dice, :name => name, :coreResult => name, :mean => mean, :chartName => chartName}
  end

  HERO_NAME_TEMPLATES = {
    1 => {:text => 'ベースＡ＋ベースＢ', :elements => ['ベースＡ', 'ベースＢ']},
    2 => {:text => 'ベースＢ', :elements => ['ベースＢ']},
    3 => {:text => 'ベースＢ×２回', :elements => ['ベースＢ', 'ベースＢ']},
    4 => {:text => 'ベースＢ＋ベースＣ', :elements => ['ベースＢ', 'ベースＣ']},
    5 => {:text => 'ベースＡ＋ベースＢ＋ベースＣ', :elements => ['ベースＡ', 'ベースＢ', 'ベースＣ']},
    6 => {:text => 'ベースＡ＋ベースＢ×２回',         :elements => ['ベースＡ', 'ベースＢ', 'ベースＢ']},
    7 => {:text => 'ベースＢ×２回＋ベースＣ',         :elements => ['ベースＢ', 'ベースＢ', 'ベースＣ']},
    8 => {:text => '（ベースＢ）・オブ・（ベースＢ）', :elements => ['ベースＢ', '・オブ・', 'ベースＢ']},
    9 => {:text => '（ベースＢ）・ザ・（ベースＢ）', :elements => ['ベースＢ', '・ザ・', 'ベースＢ']},
    10 => {:text => '任意', :elements => ['任意']},
  }.freeze

  HERO_NAME_BASE_CHARTS = {
    'ベースＡ' => {
      1 => 'ザ・',
      2 => 'キャプテン・',
      3 => 'ミスター／ミス／ミセス・',
      4 => 'ドクター／プロフェッサー・',
      5 => 'ロード／バロン／ジェネラル・',
      6 => 'マン・オブ・',
      7 => '［強さ］',
      8 => '［色］',
      9 => 'マダム／ミドル・',
      10 => '数字（１～10）・',
    },
    'ベースＢ' => {
      1 => '［神話／夢］',
      2 => '［武器］',
      3 => '［動物］',
      4 => '［鳥］',
      5 => '［虫／爬虫類］',
      6 => '［部位］',
      7 => '［光］',
      8 => '［攻撃］',
      9 => '［その他］',
      10 => '数字（１～10）・',
    },
    'ベースＣ' => {
      1 => 'マン／ウーマン',
      2 => 'ボーイ／ガール',
      3 => 'マスク／フード',
      4 => 'ライダー',
      5 => 'マスター',
      6 => 'ファイター／ソルジャー',
      7 => 'キング／クイーン',
      8 => '［色］',
      9 => 'ヒーロー／スペシャル',
      10 => 'ヒーロー／スペシャル',
    },
  }.freeze

  HERO_NAME_ELEMENT_CHARTS = {
    '部位' => {
      1 => ['ハート', '心臓'],
      2 => ['フェイス', '顔'],
      3 => ['アーム', '腕'],
      4 => ['ショルダー', '肩'],
      5 => ['ヘッド', '頭'],
      6 => ['アイ', '眼'],
      7 => ['フィスト', '拳'],
      8 => ['ハンド', '手'],
      9 => ['クロウ', '爪'],
      10 => ['ボーン', '骨'],
    },
    '武器' => {
      1 => ['ナイヴス', '短剣'],
      2 => ['ソード', '剣'],
      3 => ['ハンマー', '鎚'],
      4 => ['ガン', '銃'],
      5 => ['スティール', '刃'],
      6 => ['タスク', '牙'],
      7 => ['ニューク', '核'],
      8 => ['アロー', '矢'],
      9 => ['ソウ', 'ノコギリ'],
      10 => ['レイザー', '剃刀'],
    },
    '色' => {
      1 => ['ブラック', '黒'],
      2 => ['グリーン', '緑'],
      3 => ['ブルー', '青'],
      4 => ['イエロー', '黃'],
      5 => ['レッド', '赤'],
      6 => ['バイオレット', '紫'],
      7 => ['シルバー', '銀'],
      8 => ['ゴールド', '金'],
      9 => ['ホワイト', '白'],
      10 => ['クリア', '透明'],
    },
    '動物' => {
      1 => ['バニー', 'ウサギ'],
      2 => ['タイガー', '虎'],
      3 => ['シャーク', '鮫'],
      4 => ['キャット', '猫'],
      5 => ['コング', 'ゴリラ'],
      6 => ['ドッグ', '犬'],
      7 => ['フォックス', '狐'],
      8 => ['パンサー', '豹'],
      9 => ['アス', 'ロバ'],
      10 => ['バット', '蝙蝠'],
    },
    '神話／夢' => {
      1 => ['アポカリプス', '黙示録'],
      2 => ['ウォー', '戦争'],
      3 => ['エターナル', '永遠'],
      4 => ['エンジェル', '天使'],
      5 => ['デビル', '悪魔'],
      6 => ['イモータル', '死なない'],
      7 => ['デス', '死神'],
      8 => ['ドリーム', '夢'],
      9 => ['ゴースト', '幽霊'],
      10 => ['デッド', '死んでいる'],
    },
    '攻撃' => {
      1 => ['ストローク', '一撃'],
      2 => ['クラッシュ', '壊す'],
      3 => ['ブロウ', '吹き飛ばす'],
      4 => ['ヒット', '打つ'],
      5 => ['パンチ', '殴る'],
      6 => ['キック', '蹴る'],
      7 => ['スラッシュ', '斬る'],
      8 => ['ペネトレイト', '貫く'],
      9 => ['ショット', '撃つ'],
      10 => ['キル', '殺す'],
    },
    'その他' => {
      1 => ['ヒューマン', '人間'],
      2 => ['エージェント', '代理人'],
      3 => ['ブースター', '泥棒'],
      4 => ['アイアン', '鉄'],
      5 => ['サンダー', '雷'],
      6 => ['ウォッチャー', '監視者'],
      7 => ['プール', '水たまり'],
      8 => ['マシーン', '機械'],
      9 => ['コールド', '冷たい'],
      10 => ['サイド', '側面'],
    },
    '鳥' => {
      1 => ['ホーク', '鷹'],
      2 => ['ファルコン', '隼'],
      3 => ['キャナリー', 'カナリア'],
      4 => ['ロビン', 'コマツグミ'],
      5 => ['イーグル', '鷲'],
      6 => ['オウル', 'フクロウ'],
      7 => ['レイブン', 'ワタリガラス'],
      8 => ['ダック', 'アヒル'],
      9 => ['ペンギン', 'ペンギン'],
      10 => ['フェニックス', '不死鳥'],
    },
    '光' => {
      1 => ['ライト', '光'],
      2 => ['シャドウ', '影'],
      3 => ['ファイアー', '炎'],
      4 => ['ダーク', '暗い'],
      5 => ['ナイト', '夜'],
      6 => ['ファントム', '幻影'],
      7 => ['トーチ', '灯火'],
      8 => ['フラッシュ', '閃光'],
      9 => ['ランタン', '手さげランプ'],
      10 => ['サン', '太陽'],
    },
    '虫／爬虫類' => {
      1 => ['ビートル', '甲虫'],
      2 => ['バタフライ／モス', '蝶／蛾'],
      3 => ['スネーク／コブラ', '蛇'],
      4 => ['アリゲーター', 'ワニ'],
      5 => ['ローカスト', 'バッタ'],
      6 => ['リザード', 'トカゲ'],
      7 => ['タートル', '亀'],
      8 => ['スパイダー', '蜘蛛'],
      9 => ['アント', 'アリ'],
      10 => ['マンティス', 'カマキリ'],
    },
    '強さ' => {
      1 => ['スーパー／ウルトラ', '超'],
      2 => ['ワンダー', '驚異的'],
      3 => ['アルティメット', '究極の'],
      4 => ['ファンタスティック', '途方もない'],
      5 => ['マイティ', '強い'],
      6 => ['インクレディブル', '凄い'],
      7 => ['アメージング', '素晴らしい'],
      8 => ['ワイルド', '狂乱の'],
      9 => ['グレイテスト', '至高の'],
      10 => ['マーベラス', '驚くべき'],
    },
  }.freeze
end
