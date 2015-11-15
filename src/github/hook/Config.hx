package github.hook;

typedef Config = {
	id : Int,
	url : String,
	test_url : String,
	ping_url : String,
	name : String,
	events : Array<String>,
	active : Bool,
	config : {
		url : String,
		content_type : String
	},
	updated_at : String,
	created_at : String
}

