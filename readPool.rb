#!/usr/bin/env ruby
#-*- coding: utf-8 -*-
#saida's bitZeny Wallet -> ZsexFk72EVrG129ZLhW7s8sQnT7t25Gwjg

require "csv"
require 'nokogiri'
require 'mechanize'
require 'io/console'

STDOUT.sync = true

speed_mode = false #1秒1件→1秒2件に
@login_url = "/bitzeny/index.php?page=login" #hostUrl以降のログインurlが異なれば変えてください
@trans_url = "/bitzeny/index.php?page=account&action=transactions" #transaction履歴のあるurl

if ARGV.size()==0 then
  puts "プールのホストアドレスを入力してください"
  puts "/bitzeny以降は省略してください"
  puts "例)https://xxxxx.xxxx.xxx"
  @poolHost = gets.chomp
  
  puts "プールのログインid(e-mail)を入力してください"
  @id = gets.chomp
  
  puts "プールのログインパスワードを入力してください"
  @ps = STDIN.noecho(&:gets).chomp
  puts ""
elsif ARGV.size() == 2 then
  @poolHost = ARGV[0]
  @id = ARGV[1]
  puts "プールのログインパスワードを入力してください"
  @ps = STDIN.noecho(&:gets)
  @ps.chomp!
  puts ""
elsif ARGV.size() == 3 then
  @poolHost = ARGV[0]
  @id = ARGV[1]
  @ps = ARGV[2]
elsif ARGV.size() == 4 then
  @poolHost = ARGV[0]
  @id = ARGV[1]
  @ps = ARGV[2]
  @speed_mode = ARGV[3].to_s
elsif ARGV.size() == 6 then
  @poolHost = ARGV[0]
  @id = ARGV[1]
  @ps = ARGV[2]
  @speed_mode = ARGV[3]
  @login_url = ARGV[4]
  @trans_url = ARGV[5]
elsif ARGV.size()!=3 then
  puts "引数は[poolHost][id][password]の3つ必要です"
  puts "例) https://xxxxx.xxxx xxxx.@example.com pass"
  sleep 1
  exit
end
puts "出力ファイル名を入力してください(csvで上書き出力されます"
@out_name = STDIN.gets.chomp

puts "取得開始"
#各データ保存用クラス
class TransData
  attr_accessor :unique_id
  attr_reader :id, :date, :txType, :status, :paymentAd, :tx, :block, :amount
  def set(id, date, txType, status, paymentAd, tx, block, amount)
    @unique_id = id
    @id = id
    @date = date
    @txType = txType
    @status = status
    @paymentAd = paymentAd
    @tx = tx
    @block = block
    @amount = amount
  end
  
  def pt
    puts id
    puts date
    puts txType
    puts status
    puts paymentAd
    puts tx
    puts block
    puts amount
  end
  
#配列風要素取得
  def get(i)
   case i
   when 0 then
     return id
   when 1 then
     return date
   when 2 then
     return txType
   when 3 then
     return status
   when 4 then
     return paymentAd
   when 5 then
     return tx
   when 6 then
     return block
   when 7 then
     return amount
   end
  end

  def hash
    @unique_id.hash
  end

  def eql?(other)
    self == other
  end

  def ==(other)
    @unique_id == other.unique_id
  end
end

#ログインチェック(doc内にlastログイン表示があるか
def login?(doc)
  #check
  alerts = doc.css("#lastlogin")
  if(alerts.size == 0) then
    puts "login err"
    return false
  end
  return true
end


#ログイン処理
def login(agent)
  doc = nil
  begin
    pages = agent.get(@poolHost.to_s + @login_url.to_s) do |page|
      second_stage = page.form_with(id: "loginForm") do |form|
        form.username = @id.to_s
        form.password = @ps.to_s
      end.submit
      doc = Nokogiri::HTML(second_stage.content.toutf8)
    end
    
    rescue => error
    
    puts error
    puts "接続できません、poolHostが正しいか確認してください"
    sleep 2
    exit
  end
  
  #check
  if(!login?(doc)) then
    sleep 2
    exit
  end
  
  return doc
end


#全部見終えたか
def checkEnd(doc)
  alert = doc.css('#page-wrapper').first
  alerts = alert.css('#static')
  alerts.each do |alert|
    if alert.content.to_s.include?("Could not find any transaction") then
      return true
    end
  end
  return false
end

#終了処理
def fin(transes)
  transes.uniq! #重複要素削除(ID比較)
  #csv書き込み
  CSV.open(@out_name+".csv",'w', :force_quotes => true) do |text|
    transes.each do |tr|
      text << [tr.get(0),tr.get(1),tr.get(2),tr.get(3),tr.get(4),tr.get(5),tr.get(6),tr.get(7)]
    end
  end
end

#テーブルのhtmlより要素を取得し<TransData>の配列にセットしてく
def setElement(table, transes)
  table = table.xpath(".//tbody").first
  table.xpath(".//tr").each do |datas|
    data = datas.xpath(".//td")
    id = data[0]
    date = data[1]
    txType = data[2]
    status = data[3].xpath(".//span").first
    paymentAd = data[4].xpath(".//a").first
    tx = data[5].xpath(".//a").first
    block = data[6].xpath(".//a").first
    amount = data[7].xpath(".//font").first
    data1 = TransData.new()
    data1.set(id.content, date.content, txType.content, status.content, paymentAd.content, tx.content, block.content, amount.content)
    transes.push(data1) #配列にデータ追加
  end
end

doc = nil

agent = Mechanize.new
agent.user_agent = 'getTransHis[saida_service@outlook.jp]'
login(agent)

cnt = 0
transes = [] #各データ<TransData>

is_setTitle = false
while true do
  if speed_mode && cnt != 0 then
    sleep(15) #待機
  elsif cnt != 0
    sleep(30)
  end
  pages = agent.get(@poolHost.to_s + @trans_url.to_s + "&start=" + cnt.to_s) do |page|
    #ステータスエラー 強制終了
    if page.code.to_i != 200 then
      puts "code"+ page.code.to_s + " err"
      sleep 2
      exit
    end
    #取得
    doc = Nokogiri::HTML(page.body,nil,"UTF-8")
    if(!login?(doc)) then
      puts "reLogin"
      login(agent) #再ログイン
      next
    end
  end

  #全て取得した場合
  if checkEnd(doc) then
    puts "no more find"
    fin(transes)
    sleep 2
    exit
  end

  table = doc.css('.table-responsive').first
  
  if !is_setTitle then
   titles = table.xpath(".//tr").first.xpath(".//th") #表題
   data1 = TransData.new()
   data1.set(titles[0].content,titles[1].content,titles[2].content,titles[3].content,titles[4].content,
     titles[5].content,titles[6].content,titles[7].content)
   transes.push(data1) #配列にデータ追加
   is_setTitle = true
  end
  
  setElement(table, transes) #各要素を配列にセットしてく
  cnt += 30
  puts "取得量:"+cnt.to_s
  fin(transes) #書き込み

end