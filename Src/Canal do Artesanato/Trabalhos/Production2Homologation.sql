USE [msdb]
GO

/****** Object:  Job [Canal do Artesanato - Production to Homologation]    Script Date: 03/05/2018 18:00:45 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 03/05/2018 18:00:45 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Canal do Artesanato - Production to Homologation', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Realizes the copy of production environment to homologation environment of Canal do Artesanato database', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'Guilherme Branco Stracini', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Shrink Log File]    Script Date: 03/05/2018 18:00:45 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Shrink Log File', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'ALTER DATABASE CanalDoArtesanato_Production SET RECOVERY SIMPLE;
DBCC SHRINKFILE(''CanalDoArtesanato_log'', 1);
ALTER DATABASE CanalDoArtesanato_Production SET RECOVERY FULL;', 
		@database_name=N'CanalDoArtesanato_Production', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Backup production database]    Script Date: 03/05/2018 18:00:45 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Backup production database', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=3, 
		@retry_interval=3, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'BACKUP DATABASE [CanalDoArtesanato_Production] TO  DISK = N''C:\Databases\Backup\CanalDoArtesanato_Production.bak'' WITH NOFORMAT, NOINIT,  NAME = N''CanalDoArtesanato_Production-Completo Banco de Dados Backup'', SKIP, NOREWIND, NOUNLOAD,  STATS = 10;
GO
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Set homologation single user]    Script Date: 03/05/2018 18:00:45 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Set homologation single user', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'ALTER DATABASE [CanalDoArtesanato_Homologation] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Restore homologation database]    Script Date: 03/05/2018 18:00:45 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Restore homologation database', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=4, 
		@on_fail_step_id=7, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'RESTORE DATABASE [CanalDoArtesanato_Homologation] FROM  DISK = N''C:\Databases\Backup\CanalDoArtesanato_Production.bak'' WITH  FILE = 1,  MOVE N''CanalDoArtesanato'' TO N''C:\Databases\Data\CanalDoArtesanato_Homologation.mdf'', NOUNLOAD,  REPLACE,  STATS = 5;
GO', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Truncate tables]    Script Date: 03/05/2018 18:00:45 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Truncate tables', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'TRUNCATE TABLE [Configurations];
TRUNCATE TABLE [ELMAH_Error];
TRUNCATE TABLE [UsersAccessLogs];
TRUNCATE TABLE [CrawlersLogs];
TRUNCATE TABLE [ApplicationsAccessLogs];
TRUNCATE TABLE [MiniProfilers]
TRUNCATE TABLE [MiniProfilerTimings]
DELETE FROM [Applications];
DBCC CHECKIDENT ([Applications], RESEED, 0);', 
		@database_name=N'CanalDoArtesanato_Homologation', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Insert Applications]    Script Date: 03/05/2018 18:00:45 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Insert Applications', 
		@step_id=6, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'INSERT INTO [CanalDoArtesanato_Homologation].[dbo].[Applications] (Token, Source, Name, IsActive, Modules) VALUES (''4D289E8E-A46A-421F-B5C0-7E272C79EA2E'', 0, ''Integração Service'', 1, 9);
INSERT INTO [CanalDoArtesanato_Homologation].[dbo].[Applications] (Token, Source, Name, IsActive, Modules) VALUES (''1C49FF3A-94FC-473B-8A04-C1FCAC29AA11'', 0, ''Notificações'', 1, 6);
INSERT INTO [CanalDoArtesanato_Homologation].[dbo].[Applications] (Token, Source, Name, IsActive, Modules) VALUES (''662F23E0-E92F-49A6-A17D-90EB74323B1A'', 0, ''Pagamentos'', 1, 8);
INSERT INTO [CanalDoArtesanato_Homologation].[dbo].[Applications] (Token, Source, Name, IsActive, Modules) VALUES (''7F35AB26-413A-4FD5-B2EA-706616AEB669'', 0, ''Manutenção'', 1, 2);
INSERT INTO [CanalDoArtesanato_Homologation].[dbo].[Applications] (Token, Source, Name, IsActive, Modules) VALUES (''9ADBF20D-EC78-4472-B474-6763514A22C7'', 3, ''Visualizador de Pedidos'', 1, 1);
INSERT INTO [CanalDoArtesanato_Homologation].[dbo].[Applications] (Token, Source, Name, IsActive, Modules) VALUES (''1fe23959-849a-4d1e-85bd-8e2f1d70385b'', 3, ''Aplicativo Android'', 1, 1);
INSERT INTO [CanalDoArtesanato_Homologation].[dbo].[Applications] (Token, Source, Name, IsActive, Modules) VALUES (''6fd009d2-45ce-4c95-9e7b-57a4c3aced32'', 3, ''Aplicativo iOS'', 1, 1);', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Set homologation multi user]    Script Date: 03/05/2018 18:00:45 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Set homologation multi user', 
		@step_id=7, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'ALTER DATABASE CanalDoArtesanato_Homologation SET MULTI_USER WITH ROLLBACK IMMEDIATE;', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Delete backup file]    Script Date: 03/05/2018 18:00:45 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Delete backup file', 
		@step_id=8, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXECUTE master.dbo.xp_delete_file 0,N''C:\Databases\Backup\CanalDoArtesanato_Production.bak''
GO', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

