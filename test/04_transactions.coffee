pg = require "../"

connectionStr = "pg://postgres:123456@localhost:5432/TestDB?some_param=whatever"

QUERY_DROP = "DROP TABLE IF EXISTS numbers;"
QUERY_CREATE = "CREATE TABLE IF NOT EXISTS numbers (_id bigserial primary key, number int NOT NULL);"

describe "Transactions", ->
	@timeout 10000 # 10sec
	db = pg connectionStr
	db.on 'error', (err) ->
			return done err if err?

	beforeEach ->
		#clear db-table numbers
		db.query QUERY_DROP   #ignore error
		db.query QUERY_CREATE #ignore error

	it "BEGIN - COMMIT", (done) ->
		INSERT_COUNT = 10

		db.begin()
		db.insert "numbers", number: i for i in [1..INSERT_COUNT] # 1-10
		db.commit()
		db.queryOne "SELECT COUNT(*) FROM numbers;", (err, res) -> #ignore errors
			return done err if err?
			return done() if (parseInt res.count, 10) is INSERT_COUNT

	it "BEGIN - ROLLBACK - COMMIT", (done) ->
		INSERT_COUNT = 10

		db.begin()
		db.insert "numbers", number: i for i in [1..INSERT_COUNT] # 1-10
		db.rollback()
		db.queryOne "SELECT COUNT(*) FROM numbers;", (err, res) -> #ignore errors
			return done err if err?
			return done() if (parseInt res.count, 10) is 0

	it "BEGIN - SAVEPOINT - ROLLBACK - COMMIT", (done) ->
		INSERT_COUNT = 10

		db.begin()
		db.insert "numbers", number: i for i in [1..INSERT_COUNT] # 1-10
		db.savepoint "my_savepoint"
		db.insert "numbers", number: i for i in [1..INSERT_COUNT] # 1-10
		db.rollback()
		db.commit()
		db.queryOne "SELECT COUNT(*) FROM numbers;", (err, res) ->
			return done err if err?
			return done() if (parseInt res.count, 10) is 0

	it "BEGIN - SAVEPOINT - ROLLBACK TO - COMMIT", (done) ->
		INSERT_COUNT = 10

		db.begin()
		db.insert "numbers", number: i for i in [1..INSERT_COUNT] # 1-10
		db.savepoint "my_savepoint"
		db.insert "numbers", number: i for i in [1..INSERT_COUNT] # 1-10
		db.rollback "my_savepoint"
		db.commit()
		db.queryOne "SELECT COUNT(*) FROM numbers;", (err, res) ->
			return done err if err?
			return done() if (parseInt res.count, 10) is INSERT_COUNT

	it "nested transaction block", (done) ->
		INSERT_COUNT = 10

		db.begin()
		db.insert "numbers", number: i for i in [1..INSERT_COUNT] # 1-10
		db.savepoint "my_savepoint"
		db.insert "numbers", number: i for i in [1..INSERT_COUNT] # 1-10
		db.begin()
		db.rollback "my_savepoint" #will not work
		db.insert "numbers", number: i for i in [INSERT_COUNT..1] # 10-1
		db.commit()
		db.rollback "my_savepoint" #will work
		db.commit()
		# result should be 1-10 10-1
		db.queryOne "SELECT COUNT(*) FROM numbers;", (err, res) ->
			db.end()
			return done err if err?
			return done() if parseInt(res.count, 10) is 2*INSERT_COUNT