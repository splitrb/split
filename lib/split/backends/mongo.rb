require 'mongo'

module Split
  module Backends
    module Mongo
      def server=(url)
        @conn = ::Mongo::Connection.new
        @db   = @conn['sample-db']
        @server = @db['test']
      end

      def server
        return @server if @server
        self.server = 'localhost'
        self.server
      end

      def clean
        self.server.drop
      end

      def exists?(experiment_name)
        self.server.count(:name => experiment_name) > 0
      end

      def find(experiment_name)
        self.server.find(:name => experiment_name).first
      end

      def save(experiment_name, alternatives, time)
        self.server.insert({:name => experiment_name, 
                            :created_at => time,
                            :version => 0,
                            :alternatives => alternatives.map{|a| {
                              :name => a.name,
                              :participant_count => 0,
                              :completed_count => 0
                              }}})
      end

      def alternatives(experiment_name)
        self.find(experiment_name)['alternatives']
      end

      def start_time(experiment_name)
        self.find(experiment_name)['created_at']
      end

      def delete(experiment_name)
        self.server.remove('name' => experiment_name)
      end

      def version(experiment_name)
        self.find(experiment_name)['version']
      end
      
      def winner(experiment_name)
        self.find(experiment_name)['winner']
      end
      
      def set_winner(experiment_name, winner)
        self.server.update({"name" => experiment_name}, {"$set" => {"winner" => winner}})
      end
      
      def reset_winner(experiment_name)
        self.server.update({"name" => experiment_name}, {"$set" => {"winner" => nil}})
      end
      
      def all_experiments
        self.server.find.to_a
      end
      
      def increment_version(experiment_name)
        self.server.update({:name => experiment_name},{:$inc => {:version => 1}})
      end
      
      def alternative_names(experiment_name)
        p self.alternatives(experiment_name)
        self.alternatives(experiment_name).map{|a| a['name']}
      end

      def alternative(experiment_name, alternative)
        self.alternatives(experiment_name).find{|a| a['name'] == alternative}
      end

      def alternative_participant_count(experiment_name, alternative)
        self.alternative(experiment_name, alternative)['participant_count']
      end

      def alternative_completed_count(experiment_name, alternative)
        self.alternative(experiment_name, alternative)['completed_count']
      end
      
      def incr_alternative_participant_count(experiment_name, alternative)
        self.server.update({'name' => experiment_name, "alternatives.name" => alternative}, 
                            {"$incr" => "participant_count"})
      end

      def incr_alternative_completed_count(experiment_name, alternative)
        self.server.update({'name' => experiment_name, "alternatives.name" => alternative}, 
                            {"$incr" => "completed_count"})
      end

      def reset(experiment_name, alternative)
        self.server.update({'name' => experiment_name, "alternatives.name" => alternative}, 
                            {"$set" => {'completed_count' => 0, 'participant_count' => 0}})
      end
    end
  end
end