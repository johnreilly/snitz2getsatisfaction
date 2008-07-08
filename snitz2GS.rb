require 'rubygems'
require 'activerecord'

# Add ids to these lists to skip them during export.
rejected_member_ids = [1] #skip the administrator
rejected_topic_ids  = []
rejected_reply_ids  = []
rejected_forum_ids  = [29, 30, 33]

#############################
### Active Record Setup
#############################
ActiveRecord::Base.establish_connection(
    :adapter  => "mysql",
    :host     => "localhost",
    :username => "root",
    :password => "",
    :database => "old_trms_forum"
  )

class Forum < ActiveRecord::Base
  set_table_name  "forum_forum"
  set_primary_key "FORUM_ID"
  
  has_many :topics, :foreign_key => "FORUM_ID"
end

class Member < ActiveRecord::Base
  set_table_name  "forum_members"
  set_primary_key "MEMBER_ID"
  
  has_many :topics,   :foreign_key => "T_AUTHOR"
  has_many :replies,  :foreign_key => "R_AUTHOR"
end

class Topic < ActiveRecord::Base
  set_table_name  "forum_topics"
  set_primary_key "TOPIC_ID"
  
  has_many    :replies, :foreign_key => "TOPIC_ID"
  belongs_to  :forum,   :foreign_key => "FORUM_ID"
  belongs_to  :member,  :foreign_key => "T_AUTHOR"
end

class Reply < ActiveRecord::Base
  set_table_name  "forum_replies"
  set_primary_key "REPLY_ID"
  
  belongs_to :member, :foreign_key => "R_AUTHOR"
  belongs_to :topic,  :foreign_key => "TOPIC_ID"
  belongs_to :forum,  :foreign_key => "FORUM_ID"
end


#############################
### Data Conversion
#############################

### Members
member_list = []
Member.all.each do |m| 
  next if rejected_member_ids.include? m.MEMBER_ID
  member = {
    'nick'          => m.M_NAME,
    'personal_url'  => m.M_HOMEPAGE,
    'email'         => m.M_EMAIL,
    'id'            => m.MEMBER_ID
  }
  member_list << member
end

### Topics
topic_list = []
Topic.all.each do |t| 
  next if rejected_topic_ids.include? t.TOPIC_ID
  next if rejected_forum_ids.include? t.FORUM_ID
  
  #figure out what style this topic is...
  style = 'discussion'
  case t.T_SUBJECT
    when /\?/
      style = "question"
    when /question/i
      style = "question"
    when /problem|error|fail|issue/i
      style = "problem"
    when /feature|idea/i
      style = "idea"
  end
  
  # find some tags
  # these tags are specific to our content, you should modify as needed.
  tags = []
  tags << 'cablecast' if t.T_SUBJECT.downcase.include? 'cablecast'
  tags << 'carousel' if t.T_SUBJECT.downcase.include? 'carousel'
  tags << 'cablecast' if t.T_MESSAGE.downcase.include? 'cablecast'
  tags << 'carousel' if t.T_MESSAGE.downcase.include? 'carousel'
  tags << 'frontdoor' if t.T_SUBJECT.downcase.include? 'frontdoor'
  tags << 'frontdoor' if t.T_SUBJECT.downcase.include? 'front door'
  tags << 'release' if t.T_SUBJECT.downcase.include? 'announcing ca'
  tags << 'autopilot' if t.T_SUBJECT.downcase.include? 'autopilot'
  tags << 'announcement' if t.T_SUBJECT.downcase.include? 'announc'
  tags << 'bug' if t.T_SUBJECT.downcase.include? 'bug'
  tags << 'template' if t.T_SUBJECT.downcase.include? 'template'
  tags << 'video' if t.T_SUBJECT.downcase.include? 'video'
  tags << 'audio' if t.T_SUBJECT.downcase.include? 'audio'
  tags << 'rss' if t.T_SUBJECT.downcase.include? 'rss'
  tags << 'cabledisplay' if t.T_SUBJECT.downcase.include? 'cabledisplay'
  tags << 'cabledisplay' if t.T_SUBJECT.downcase.include? 'cable display'
  tags << 'vod' if t.T_SUBJECT.downcase.include? 'vod'
  tags << 'publicsite' if t.T_SUBJECT.downcase.include? 'public'
  tags << 'stream' if t.T_SUBJECT.downcase.include? 'stream'
  tags << 'schedule' if t.T_SUBJECT.downcase.include? 'schedule'
  tags << 'vsx' if t.T_SUBJECT.downcase.include? 'vsx'
  tags << 'vs4' if t.T_SUBJECT.downcase.include? 'vs4'
  tags << 'sx' if t.T_SUBJECT.downcase.include? ' sx' #space is intentional.
  tags.uniq!
  
  # associate with products, based on the forum name, topic subject, and topic message
  products = []
  products << 'cablecast' if t.forum.F_SUBJECT.downcase.include? 'cablecast'
  products << 'carousel' if t.forum.F_SUBJECT.downcase.include? 'carousel'
  products << 'cablecast' if t.T_SUBJECT.downcase.include? 'cablecast'
  products << 'carousel' if t.T_SUBJECT.downcase.include? 'carousel'
  products << 'cablecast' if t.T_MESSAGE.downcase.include? 'cablecast'
  products << 'carousel' if t.T_MESSAGE.downcase.include? 'carousel'
  products.uniq!
  
  topic = {
    'user_id'           => t.member.MEMBER_ID,
    'subject'           => t.T_SUBJECT,
    'additional_detail' => t.T_MESSAGE,
    'created_at'        => DateTime.parse(t.T_DATE).to_s(:db),
    'style'             => style,
    'tags'              => tags.join(','),
    'products'          => products.join(','),
    'id'                => t.TOPIC_ID,
    'opaque_id'         => t.TOPIC_ID
  }
  topic_list << topic
end

### Replies
reply_list = []
Reply.all.each do |r| 
  # For some reason, r.REPLY_ID throws a method_missing error. Don't know why.
  # More details here: http://johnreilly.tumblr.com/post/39200511/strange-activerecord-error
  next if rejected_reply_ids.include? r["REPLY_ID"]
  next if rejected_forum_ids.include? r["FORUM_ID"]
  
  reply = {
    'user_id'       => r.member.MEMBER_ID,
    'created_at'    => DateTime.parse(r["R_DATE"]).to_s(:db),
    'content'       => r["R_MESSAGE"],
    'tags'          => '',
    'topic_id'      => r.topic.TOPIC_ID,
    'opaque_id'     => r["REPLY_ID"]
  }
  reply_list << reply
end



#############################
### Wrap up the data and export as yaml
#############################
export = { 
  'replies' => reply_list,
  'topics'  => topic_list,
  'users'   => member_list
}
File.open('forum_output.yml', 'w') {|f| f.print export.to_yaml}
















