require "csv"
require 'date'
require 'open-uri'

@zny_jpy_csv = "zny-jpy-tmp.csv" #値段一覧csv
#readfile = "out.csv"
#outfile = "out2.csv" #出力csv

#Dateを年月日に変換
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
   puts "DL完了しました(zny-jpy-tmp.csv)"
  
  rescue => error
   puts error
   puts "DLに失敗しました。相場のcsvファイルを指定して読み込みます。"
   puts "ファイル名を入力してください"
   @zny_jpy_csv = gets.chomp
  end
end


puts "プールのTransaction Historyのcsvファイルを指定してください(拡張子必須)"
STDOUT.flush
readfile = gets.chomp
puts "出力するファイル名を指定してください(拡張子不要)"
outfile = gets.chomp+".csv"


amountCow = 7 #読み込みcsvの何列目にamountがあるか
dateCow = 1 #読み込みcsvの何列目に日付があるか

getZnyJpy#DL

#過去の値段をhashへ
price_hash = {}
CSV.foreach(@zny_jpy_csv, headers: true) do |row|
  date = DateTime.parse(row[0])
  price_hash[getDateHash(date)] = row[1].to_f #日付をhash,値を値段
end


sum = 0.0 #合計

begin
#書き込み
CSV.open(outfile,"w", :force_quotes => true) do |outcs|
  first = true
  #プールからの履歴
  CSV.foreach(readfile) do |row|
    if first then#ヘッダー追記
      first = false
      row.push("yen")
      outcs << row
      next
    end
    
    price = price_hash[getDateHash(DateTime.parse(row[dateCow]))]*row[amountCow].to_f#マイニング量(yen
    sum = sum + price
    row.push(price)
    outcs << row
  end
  
end

rescue => err
 puts err
end

puts "合計(yen): "+sum.to_s
sleep 2
