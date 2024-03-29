unless $CELLULOID_BACKPORTED == false
  RSpec.describe Celluloid::Supervisor, actor_system: :global do
    class SubordinateDead < Celluloid::Error; end

    class Subordinate
      include Celluloid
      attr_reader :state

      def initialize(state)
        @state = state
      end

      def crack_the_whip
        case @state
        when :idle
          @state = :working
        else fail SubordinateDead, "the spec purposely crashed me :("
        end
      end
    end

    it "restarts actors when they die" do
      supervisor = Celluloid::Supervisor.supervise(Subordinate, :idle)
      subordinate = supervisor.actors.first
      expect(subordinate.state).to be(:idle)

      subordinate.crack_the_whip
      expect(subordinate.state).to be(:working)

      expect do
        subordinate.crack_the_whip
      end.to raise_exception(SubordinateDead)
      sleep 0.1 # hax to prevent race :(
      expect(subordinate).not_to be_alive

      new_subordinate = supervisor.actors.first
      expect(new_subordinate).not_to eq subordinate
      expect(new_subordinate.state).to eq :idle
    end

    it "registers actors and reregisters them when they die" do
      Celluloid::Supervisor.supervise_as(:subordinate, Subordinate, :idle)
      subordinate = Celluloid::Actor[:subordinate]
      expect(subordinate.state).to be(:idle)

      subordinate.crack_the_whip
      expect(subordinate.state).to be(:working)

      expect do
        subordinate.crack_the_whip
      end.to raise_exception(SubordinateDead)
      sleep 0.1 # hax to prevent race :(
      expect(subordinate).not_to be_alive

      new_subordinate = Celluloid::Actor[:subordinate]
      expect(new_subordinate).not_to eq subordinate
      expect(new_subordinate.state).to eq :idle
    end

    it "creates supervisors via Actor.supervise" do
      supervisor = Subordinate.supervise(:working)
      subordinate = supervisor.actors.first
      expect(subordinate.state).to be(:working)

      expect do
        subordinate.crack_the_whip
      end.to raise_exception(SubordinateDead)
      sleep 0.1 # hax to prevent race :(
      expect(subordinate).not_to be_alive

      new_subordinate = supervisor.actors.first
      expect(new_subordinate).not_to eq subordinate
      expect(new_subordinate.state).to eq :working
    end

    it "creates supervisors and registers actors via Actor.supervise_as" do
      supervisor = Subordinate.supervise_as(:subordinate, :working)
      subordinate = Celluloid::Actor[:subordinate]
      expect(subordinate.state).to be(:working)

      expect do
        subordinate.crack_the_whip
      end.to raise_exception(SubordinateDead)
      sleep 0.1 # hax to prevent race :(
      expect(subordinate).not_to be_alive

      new_subordinate = supervisor.actors.first
      expect(new_subordinate).not_to eq subordinate
      expect(new_subordinate.state).to be(:working)
    end

    it "removes an actor if it terminates cleanly" do
      supervisor = Subordinate.supervise(:working)
      subordinate = supervisor.actors.first

      expect(supervisor.actors).to eq([subordinate])

      subordinate.terminate

      expect(supervisor.actors).to be_empty
    end
  end
end
