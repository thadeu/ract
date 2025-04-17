class Table; end

class Table::Base
  async def self.execute(...)
    new(...).execute!
  end

  def initialize(user_id:)
    @user_id = user_id
  end

  def execute!
    sleep 0.01
    @user_id
  end
end

class Table::Posts < Table::Base
  def execute!
    @user_id
  end
end

class MethodAsync
  async def self.execute(...)
    new(...).execute!
  end

  def initialize(user_id:)
    @user_id = user_id
  end

  def execute!
    sleep 0.01
    @user_id
  end

  def with_ract
    Ract {
      sleep 0.01
      @user_id
    }
  end
end
