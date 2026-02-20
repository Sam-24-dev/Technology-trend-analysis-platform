from tech_normalization import normalize_technology_name, normalize_for_match


def test_normalize_technology_name_known_values():
	assert normalize_technology_name("python") == "Python"
	assert normalize_technology_name("vue 3") == "Vue.js"
	assert normalize_technology_name("ia/machine learning") == "AI/ML"


def test_normalize_technology_name_unknown_to_title_case():
	assert normalize_technology_name("mytech") == "Mytech"


def test_normalize_for_match_aliases():
	assert normalize_for_match("JavaScript") == "javascript"
	assert normalize_for_match("js ecosystem") == "javascript"
	assert normalize_for_match("asp.net core") == "c#"
