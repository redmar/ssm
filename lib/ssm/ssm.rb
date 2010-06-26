module SimpleStateMachine
  
  def event event_name, state_transitions
    @state_machine ||= StateMachine.new self
    @state_machine.register_event event_name, state_transitions
  end
  
  def state_machine
    @state_machine
  end
  
  class StateMachine
    
    attr_reader :events

    def initialize subject
      @subject = subject
      @events  = {}
    end
    
    def register_event event_name, state_transitions
      @events[event_name] ||= {}
      state_transitions.each do |from, to|
        @events[event_name][from.to_s] = to.to_s
        define_state_helper_method from
        define_state_helper_method to
        unless @subject.method_defined?("with_managed_state_#{event_name}")
          decorate_event_method(event_name) 
        end
      end
    end

    def decorate_event_method event_name
      @subject.send(:define_method, "with_managed_state_#{event_name}") do |*args|
        state_machine  = self.class.state_machine
        state = @state || self.state
        return ssm_transition(event_name, state, state_machine.events[event_name][state]) do
          send("without_managed_state_#{event_name}", *args)
        end
      end
      @subject.send :alias_method, "without_managed_state_#{event_name}", event_name
      @subject.send :alias_method, event_name, "with_managed_state_#{event_name}"
      @subject.send :include, InstanceMethods
    end
    
    def define_state_helper_method state
      @subject.send(:define_method, "#{state.to_s}?") do
        @state == state.to_s || self.state == state.to_s
      end
    end
    
  end
  
  module InstanceMethods
    
    def set_initial_state(state, state_method='state')
      self.class.send(:define_method, state_method + '=') do |new_state|
        @state = new_state.to_s
      end
      self.class.send(:define_method, state_method) do
        @state
      end
      send(state_method + '=', state)
    end
  
    def ssm_transition(event_name, from, to)
      if to
        @next_state = to
        result = yield
        if @__cancel_state_transition
          @__cancel_state_transition = false
        else
          state = @state = to
          send :state_transition_succeeded_callback, @state
        end
      else
        # implement your own logic: i.e. set errors in active validations
        send :illegal_state_transition_callback, event_name
      end
      result
    end
  
    def illegal_state_transition_callback event_name
      # override with your own implementation, like setting errors in your model
      raise "You cannot '#{event_name.inspect}' when state is '#{state.inspect}'"
    end
  
    def state_transition_succeeded_callback(state)
    end
    
    def cancel_state_transition
      @__cancel_state_transition = true
    end
  
  end
  
end