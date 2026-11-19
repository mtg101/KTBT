extends GdUnitTestSuite
## Tests for scripts/rules/memories.gd: the facts about a person and who knows them, lines that
## contradict them, and threads (something coming up, for the owner to ask about next time).

const Memories = preload("res://scripts/rules/memories.gd")
const Text = preload("res://scripts/rules/text.gd")


func test_facts_know_who_heard_them() -> void:
	var regular := {}
	var heard := [{"text": "double shift at the hospital again", "by": ["owner"]}, {"text": "my cat mochi hates the rain", "by": ["da-eun"]}]
	assert_array(Memories.who_heard("a nurse at the hospital", heard)).is_equal(["owner"])
	assert_array(Memories.who_heard("a cat called Mochi", heard)).is_equal(["da-eun"])  # (said in a chat: the owner wasn't there)
	assert_bool(Memories.learn_fact(regular, "job", "nurse at the hospital", 4, ["owner"])).is_true()
	assert_bool(Memories.learn_fact(regular, "pet", "a cat called Mochi", 4, ["da-eun"])).is_true()
	assert_dict(Memories.facts_known_by(regular, "owner")).is_equal({"job": "nurse at the hospital"})
	assert_dict(Memories.facts_known_by(regular, "da-eun")).is_equal({"pet": "a cat called Mochi"})
	assert_dict(Memories.facts_known_by(regular)).is_equal({"job": "nurse at the hospital", "pet": "a cat called Mochi"})  # (they know their own)
	assert_bool(Memories.learn_fact(regular, "pet", "a cat called Mochi", 6, ["owner"])).is_true()  # (said again, to the owner this time)
	assert_array(regular["facts"]["pet"]["known_by"]).is_equal(["da-eun", "owner"])
	assert_bool(Memories.learn_fact(regular, "pet", "a cat called Mochi", 7, ["owner"])).is_false()  # (nothing new)
	assert_bool(Memories.learn_fact(regular, "job", "", 7, ["owner"])).is_false()
	assert_str(Memories.fact_text("old-style words")).is_equal("old-style words")


func test_a_line_that_contradicts_their_family_is_sent_back() -> void:
	assert_str(Memories.family_state("lost his wife three years ago; a son in Busan")).is_equal("widowed")
	assert_str(Memories.family_state("divorced, sees the kids at weekends")).is_equal("divorced")
	assert_str(Memories.family_state("never married")).is_equal("single")
	assert_str(Memories.family_state("married, two daughters")).is_equal("married")
	assert_str(Memories.family_state("her mum wants her to quit")).is_empty()
	assert_str(Memories.kids_state("lost his wife; a son in Busan")).is_equal("some")
	assert_str(Memories.kids_state("married, no kids")).is_equal("none")
	# 15 Nov: a widower's "my wife's nagging".
	var widower := "lost his wife three years ago"
	var problem := Memories.contradiction("My wife's nagging me to quit drinking again.", "Oh Sang-chul", widower)
	assert_str(problem).contains("Oh Sang-chul is widowed").contains(widower)
	assert_str(Text.problem_kind(problem)).is_equal("contradicts what they've said")
	assert_str(Memories.contradiction("My wife used to make this every winter.", "Oh Sang-chul", widower)).is_empty()  # (remembering her)
	assert_str(Memories.contradiction("I miss my wife on nights like this.", "Oh Sang-chul", widower)).is_empty()
	assert_str(Memories.contradiction("My wife says hello.", "Kim", "married, two daughters")).is_empty()
	assert_str(Memories.contradiction("I'm single, you know.", "Kim", "married, two daughters")).contains("is married")
	assert_str(Memories.contradiction("My son never calls.", "Lee", "married, no kids")).contains("has no children")
	assert_str(Memories.contradiction("I don't have kids, thank god.", "Lee", "married, two daughters")).contains("has children")
	assert_str(Memories.contradiction("My wife's nagging me.", "Someone new", "")).is_empty()  # (nothing known)


func test_threads_for_next_time() -> void:
	var regular := {}
	assert_dict(Memories.open_thread(regular)).is_empty()
	Memories.add_thread(regular, "a job interview on Monday", 4)
	var thread := Memories.open_thread(regular)
	assert_str(str(thread["text"])).is_equal("a job interview on Monday")
	assert_str(Memories.thread_note(thread, 7)).contains("3 nights ago").contains("a job interview on Monday").contains("asks how it went")
	assert_str(Memories.thread_note(thread, 5)).contains("last night")
	Memories.close_thread(thread, "got the job", 7)
	assert_dict(Memories.open_thread(regular)).is_empty()
	assert_str(str(regular["threads"][0]["outcome"])).is_equal("got the job")
	# Too long ago, or asked about twice with no answer: dropped.
	Memories.add_thread(regular, "moving house", 8)
	Memories.add_thread(regular, "a first date", 9)
	regular["threads"][2]["asked"] = Memories.THREAD_ASKS
	assert_int(Memories.drop_stale(regular, 12)).is_equal(1)
	assert_str(str(Memories.open_thread(regular)["text"])).is_equal("moving house")
	assert_int(Memories.drop_stale(regular, 8 + Memories.THREAD_STALE + 1)).is_equal(1)
	for i in 6:
		Memories.add_thread(regular, "a trip, number %d" % i, 40 + i)
	assert_int(regular["threads"].size()).is_equal(Memories.THREADS_KEPT)


func test_the_after_visit_memory_keeps_threads_only_if_said() -> void:
	var said := "my interview's on monday, wish me luck. the exam went fine in the end."
	var data := {"owner_remembers": "Nervous about Monday.", "they_remember": "Kind owner.", "night": "enjoyed it", "towards_owner": "warmer",
		"coming_up": "a job interview on Monday", "followed_up": "the exam went fine", "pet": "a dog called Bori"}
	assert_str(Memories.validate_memory(data, said)).is_empty()
	assert_str(str(data["coming_up"])).is_equal("a job interview on Monday")
	assert_str(str(data["followed_up"])).is_equal("the exam went fine")
	assert_str(str(data["pet"])).is_empty()  # (no dog was mentioned)


func test_impressions_the_show_and_the_tents_cat_are_not_facts() -> void:
	# 19 Nov: "seems friendly", "getting through the rest of the night", "a call from PD", the tent's cat as her pet.
	var said := "he's been chatting, seems friendly. i got a call from pd. kkamjang-i is so cute. my dog bori waits up for me. just getting through the rest of the night."
	var data := {"owner_remembers": "A nice one.", "they_remember": "Kind owner.", "night": "enjoyed it", "towards_owner": "the same",
		"other": "he's been chatting, seems friendly", "worry": "a call from PD", "pet": "Kkamjang-i, the cat", "hope": "getting through the rest of the night",
		"home": "a dog called Bori waits up for him"}
	assert_str(Memories.validate_memory(data, said, ["pd", "kkamjang-i"])).is_empty()
	for key in ["other", "worry", "pet", "hope"]:
		assert_str(str(data[key])).override_failure_message("%s kept: %s" % [key, data[key]]).is_empty()
	assert_str(str(data["home"])).is_not_empty()  # (a real one stays)
	assert_bool(Memories.is_not_a_fact("a part-time English tutor")).is_false()


func test_how_it_went_has_to_say_something_new() -> void:
	assert_bool(Memories.says_how_it_went("exam looming", "Exam looming")).is_false()  # (19 Nov: just the thing again)
	assert_bool(Memories.says_how_it_went("the exam went fine", "an exam on Friday")).is_true()


func test_two_regulars_closing_memory_is_checked() -> void:
	var first_said := "i've just started at the bakery on the corner. my sister's wedding is next month."
	var second_said := "seems quiet tonight, eh. i walk my dog bori every morning."
	var data := {"first_remembers": "Second's dog sounds lovely.", "second_remembers": "First just started at a bakery.",
		"first_fact_kind": "job", "first_fact": "works at the bakery on the corner", "second_fact_kind": "pet", "second_fact": "a dog called Bori",
		"first_coming_up": "her sister's wedding next month", "second_coming_up": "a trip to Jeju"}
	assert_str(Memories.validate_pair_memory(data, first_said, second_said)).is_empty()
	assert_str(str(data["first_fact"])).is_equal("works at the bakery on the corner")
	assert_str(str(data["second_fact"])).is_equal("a dog called Bori")
	assert_str(str(data["first_coming_up"])).is_equal("her sister's wedding next month")
	assert_str(str(data["second_coming_up"])).is_empty()  # (Jeju was never said)
	var bad := {"first_remembers": "x", "second_remembers": "y", "first_fact_kind": "star sign", "first_fact": "works at the bakery", "second_fact_kind": "other", "second_fact": "seems quiet tonight"}
	assert_str(Memories.validate_pair_memory(bad, first_said, second_said)).is_empty()
	assert_str(str(bad["first_fact"])).is_empty()  # (no such kind)
	assert_str(str(bad["second_fact"])).is_empty()  # (an impression of tonight)
	assert_str(Memories.validate_pair_memory({"first_remembers": "x"}, "", "")).is_not_empty()
	# A thread another regular heard about isn't the owner's to ask.
	var regular := {}
	Memories.add_thread(regular, "her sister's wedding", 3, ["da-eun"])
	assert_dict(Memories.open_thread(regular)).is_empty()
	assert_str(str(Memories.open_thread(regular, "da-eun")["text"])).is_equal("her sister's wedding")


func test_only_something_coming_up_is_a_thread() -> void:
	for kept in ["a job interview on Monday", "her sister's wedding next month", "moving house", "a dentist appointment on Friday", "exam tomorrow", "a week off"]:
		assert_bool(Memories.is_a_thread(kept)).override_failure_message(kept).is_true()
	# 19 Nov: what the AI offered that isn't.
	for dropped in ["friend's stories to share", "heading home to think about her troubles", "daughter's exams are over", "still looking for a new job", "research project", ""]:
		assert_bool(Memories.is_a_thread(dropped)).override_failure_message(dropped).is_false()
	var regular := {}
	Memories.add_thread(regular, "research project", 3)
	assert_bool(regular.has("threads")).is_false()
