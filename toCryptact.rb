#!/usr/bin/env ruby
#-*- coding: utf-8 -*-

require "csv"
require 'date'
require 'open-uri'

def getDate(date)
  return date.strftime("%Y-%m-%d %H:%M:%S")
end

def getDateHash(date)
  return date.year.to_s + date.month.to_s + date.mday.to_s
end

#bitZenyの相場csvを取得
def getZnyJpy

  begin
   puts "相場をDLしています..."
   url = "https://www.coingecko.com/price_charts/export/bitzeny/jpy.csv"
   filename = "zny-jpy-tmp.csv"
   open(url) do |file|
     open(filename, "w+b") do |out|
       out.write(file.read)
     end
   end
   
   @zny_jpy_csv = filename
   puts "DL完了しました(zny-jpy-tmp.csv)"
  
  rescue => error
   puts error
   puts "DLに失敗しました。相場のcsvファイルを指定して読み込みます。"
   puts "ファイル名を入力してください"
   @zny_jpy_csv = gets.chomp
  end
end

def getPriceHash
  getZnyJpy#DL
  #過去の値段をhashへ
  price_hash = {}
  CSV.foreach(@zny_jpy_csv, headers: true) do |row|
    date = DateTime.parse(row[0])
    price_hash[getDateHash(date).to_s] = row[1].to_f #日付をhash,値を値段}
  end
  
  return price_hash
end

#readfile = "out2.csv"
#outfile = "out3.csv"
#source_name = "pool"
#fee = 0

puts "readPoolで生成したファイル名を入力(拡張子必須)"
STDOUT.flush
readfile = gets.chomp

puts "出力するファイル名を入力(拡張子不要)"
outfile = gets.chomp+".csv"

puts "ソース元を入力(プール名等)"
source_name = gets.chomp

puts "手数料(yen)を入力(1回のマイニング費も含む)"
fee = gets.chomp

dateCow = 1
amountCow = 7
payaddCow = 4
#yenCow = 9

price_hash = getPriceHash #DLと各日の1単位値段
begin
#書き込み
CSV.open(outfile,"w", :force_quotes => true, :encoding => "utf-8") do |outcs|
  first = true
  #プールからの履歴
  CSV.foreach(readfile) do |row|

    if first then#ヘッダー追記
      first = false
      outcs << ["Timestamp","Action","Source","Base","Volume","Price","Counter","Fee","FeeCcy"]
      next
    end
    if row[payaddCow] != "" then 
      next#支払いは無視
    end
    date = DateTime.parse(row[dateCow])
    volume = row[amountCow]
    outcs << [getDate(date),"MINING",source_name,"ZNY",volume.to_s, price_hash[getDateHash(date).to_s].to_s, "JPY", fee.to_s, "JPY"]
  end
end
rescue => err
 puts err
 puts "書き込みエラー"
end

puts "完了"
sleep 2