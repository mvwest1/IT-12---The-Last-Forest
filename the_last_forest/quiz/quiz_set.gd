class_name QuizSet
extends Resource
## The same set is used as the pre-test (before the stage) and the post-test
## (after the stage) so pre/post scores are directly comparable.

@export_range(1, 4) var stage_index: int = 1
@export var questions: Array[QuizQuestion] = []
