module Celluloid
  # Supervise collections of actors as a group
  module Supervision
    class Group

      include Celluloid
      
      trap_exit :restart_actor

      class << self

        def deploy options
          Configuration.deploy(options,self)
        end

        # Actors or sub-applications to be supervised
        def blocks
          @blocks ||= []
        end

        # Start this application (and watch it with a supervisor)
        def run!(registry = nil)
          group = new(registry) do |g|
            blocks.each do |block|
              block.call(g)
            end
          end
          group
        end

        # Run the application in the foreground with a simple watchdog
        def run(registry = nil)
          loop do
            supervisor = run!(registry)

            # Take five, toplevel supervisor
            sleep 5 while supervisor.alive?

            Internals::Logger.error "!!! Celluloid::Supervision::Group #{self} crashed. Restarting..."
          end
        end

        # Register an actor class or a sub-group to be launched and supervised
        def supervise(*args, &block)
          blocks << lambda do |group|
            group.add(Configuration.options(args, :block => block))
          end
        end
      end

      finalizer :finalize

      # Start the group
      def initialize(registry = nil)
        @state = :initializing
        @members = []
        @registry = registry || Celluloid.actor_system.registry
        yield current_actor if block_given?
      end

      execute_block_on_receiver :initialize, :supervise, :supervise_as

      def supervise(*args, &block)
        add(Configuration.options(args, :block => block))
      end

      def add(configuration)
        Configuration.valid? configuration, true
        member = Supervision::Member.new(configuration.merge(registry: @registry))
        @members << member
        @state = :running
        Actor.current
      end

      def actors
        @members.map(&:actor)
      end

      def [](actor_name)
        @registry[actor_name]
      end

      # Restart a crashed actor
      def restart_actor(actor, reason)
        return if @state == :shutdown
        member = @members.find do |_member|
          _member.actor == actor
        end
        raise "a group member went missing. This shouldn't be!" unless member

        if reason
          exclusive { member.restart }
        else
          member.cleanup
          @members.delete(member)
        end
      end

      def shutdown
        @state = :shutdown
        finalize
      end
      
      private

      def finalize
        @members.reverse_each(&:terminate) if @members
      end
    end
  end
end