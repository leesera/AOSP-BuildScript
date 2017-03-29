require 'nokogiri' 
require 'open-uri'
def flatform s
  s.downcase.gsub(" ","")
end

cmd = ARGV[0]
url = "https://source.android.com/source/build-numbers.html"
page = Nokogiri::HTML(open(url))
driver_url = "https://developers.google.com/android/drivers"
driver_page = Nokogiri::HTML(open(driver_url))
list= page.css("div div table")[1].css("tbody tr")[1..-1]
driver_list = driver_page.css("div.devsite-article-body h3") 
modelinfo = {}
driverinfo = {}
list.map{|x| 
  td = x.css("td")[0]
  if td != nil
    modelinfo[x.css("td")[0].content ] = x.css("td")[1..-1].map{|y| y.content}
  end
  } 
case cmd 
when "show"
   query = ARGV[1]
    
    models = modelinfo.keys.map{|x| "#{x} (#{modelinfo[x][1]}, #{modelinfo[x][2]})" }
    if not query.nil?
      model = models.select{|m| flatform(m).include? flatform(query)}
      puts model
    else
      puts models.join("\n")
    end
when "build"
  driver_list.map{|d| driverinfo[flatform(d.content)] = d.next_element.css("a").map{|a| a["href"]}}
  model = ARGV[1]
  device = ARGV[2]
  if not model.nil? and not device.nil?
    info = modelinfo[model]
    if not info.nil?
      puts info 
      cmd = "mkdir AOSP-#{model};cd AOSP-#{model};repo init -u https://android.googlesource.com/platform/manifest -b #{info[0]};repo sync -j4;"
      system(cmd)

      search = [device, model].map{|x| flatform(x)} 
      dk = driverinfo.keys.select{|x| search.all? {|s| x.include? s}}[0]

      #for download device drivers
      cmd = "cd AOSP-#{model};"
      driverinfo[dk].map{|l| cmd+="wget #{l};tar -xvf #{l.split("/")[-1]};"}
      system(cmd)

      #we need to bypass asking lisence
      sh_list= `cd AOSP-#{model};ls extr*`.split("\n")
      cmd = "cd AOSP-#{model};"
      cmd += sh_list.map{|sl| `cd AOSP-#{model};strings #{sl} | grep tail`.gsub("$0",sl)}.join(";").gsub("\n","")
      javalocation = "/usr/lib/jvm/java-1.7.0-openjdk-amd64/bin/"

      cmd = cmd+";echo 'hi';source build/envsetup.sh;export PATH=#{javalocation}:$PATH;perl -e 'print \"\n21\n\"' | lunch; make -j4"
      f = File.new "script.sh","w"
      f.write(cmd)
      f.close
      system("bash script.sh")
      
    end
  else
    puts "gimme device and model info"
  end
end

