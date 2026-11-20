class_name Scenes
extends RefCounted
# 씬 경로의 단일 출처. 씬 전환은 Scenes.go(tree, Scenes.PREP)처럼 호출한다.

const TITLE := "res://scenes/Title.tscn"
const PREP := "res://scenes/Prep.tscn"
const BATTLE := "res://scenes/Main.tscn"


static func go(tree: SceneTree, path: String) -> void:
	print("[Scenes] -> %s" % path.get_file().get_basename())
	tree.change_scene_to_file(path)
