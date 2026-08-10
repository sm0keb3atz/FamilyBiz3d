extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var wallet := PlayerWalletComponent.new()
	wallet.starting_dirty_cash = 5000
	wallet.starting_clean_cash = 3000
	root.add_child(wallet)
	var world_time := WorldTimeComponent.new()
	root.add_child(world_time)
	world_time.connect_wallet(wallet)

	world_time.minute_of_day = 8 * 60
	assert(wallet.add_dirty(680, true, "Street Sales", "Weed sold"))
	world_time.minute_of_day = 10 * 60 + 30
	assert(wallet.add_clean(210, true, "Property Income", "Laundry front"))
	world_time.minute_of_day = 13 * 60
	assert(wallet.spend_clean(300, true, "Lawyer Retainer", "Legal fees"))
	world_time.minute_of_day = 17 * 60 + 15
	assert(wallet.spend_dirty(220, true, "Drug Restock", "Weed supply"))
	assert(world_time.daily_earned == 890)
	assert(world_time.daily_spent == 520)
	assert(world_time.daily_transactions.size() == 4)
	var saved := world_time.export_save_data()
	assert((saved.get("daily_transactions", []) as Array).size() == 4)

	var report_date := world_time.get_formatted_date()
	world_time.advance_minutes(WorldTimeComponent.MINUTES_PER_DAY - world_time.minute_of_day)
	var entries := world_time.get_last_day_transactions()
	var history := world_time.get_daily_report_history(7)
	assert(entries.size() == 4)
	assert(history.size() == 1)
	assert(int(history[0].get("earned", -1)) == 890)
	assert(int(history[0].get("spent", -1)) == 520)
	assert(world_time.daily_transactions.is_empty())

	var report := DailyFinancialReport.new()
	report.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(report)
	report.show_report(
		report_date, 890, 520, entries,
		wallet.dirty_cash + wallet.clean_cash, history
	)
	await process_frame
	await process_frame
	assert(report.visible)
	assert(report.find_child("CashFlowChart", true, false) != null)
	assert(report.find_child("ReportContinueButton", true, false) != null)
	assert(report.find_child("FinancialReportFrame", true, false) != null)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			var path := argument.trim_prefix("--capture=")
			var image := root.get_texture().get_image()
			assert(image.save_png(path) == OK)
			break
	print("DAILY_FINANCIAL_REPORT_SMOKE_TEST_PASS")
	quit()
