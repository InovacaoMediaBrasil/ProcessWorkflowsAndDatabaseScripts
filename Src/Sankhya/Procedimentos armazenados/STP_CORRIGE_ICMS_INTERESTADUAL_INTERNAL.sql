USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_CORRIGE_ICMS_INTERESTADUAL]    Script Date: 27/03/2017 09:04:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Rafael Turra
	Create date:	2016-03-18
	Description:	Corrige valor ICMS interestadual

	Author:			Guilherme Branco Stracini
	Change date:	2018-03-20
	Description:	Alterado para cadastrar na TGFACT que foi executado o procedimento na nota.
					Adicionado WITH (NOLOCK) nas queries
					Removido código desnecessário
	============================================= */
ALTER PROCEDURE [sankhya].[STP_CORRIGE_ICMS_INTERESTADUAL_INTERNAL] (
		@NUNOTA INT,
		@CODUSU INT
) AS
DECLARE
		@CODTIPOPER INT,
		@STATUSNFE CHAR(1)
BEGIN
	/* Seleciona tipo de operação e os dados da nota */
	SELECT	@CODTIPOPER =	CODTIPOPER, 
			@STATUSNFE =	STATUSNFE 
	FROM TGFCAB WITH (NOLOCK)
	WHERE NUNOTA = @NUNOTA

	/* Verifica se é da top 550 e está aguardando correção */
	IF @CODTIPOPER NOT IN (550, 561, 562, 600) 
	OR @STATUSNFE = 'R'
		RAISERROR('Somente são permitidas correções de notas das TOPs 550, 561, 562 e 600 e que estão aguardando correção.', 16, 1);	
	ELSE
		/* Executa um update para copiar informações da expedição para a nota */
		UPDATE TGFCAB SET 
		VLRICMS =			(SELECT SUM(VALOR) FROM TGFDIN WITH (NOLOCK) WHERE NUNOTA = @NUNOTA AND CODIMP = 1),
		VLRICMSDIFALDEST =	(SELECT SUM(VLRDIFALDEST) FROM TGFDIN WITH (NOLOCK) WHERE NUNOTA = @NUNOTA AND CODIMP = 1),
		VLRICMSDIFALREM =	(SELECT SUM(VLRDIFALREM) FROM TGFDIN WITH (NOLOCK) WHERE NUNOTA = @NUNOTA AND CODIMP = 1)
		WHERE NUNOTA = @NUNOTA			
		
	INSERT INTO TGFACT (NUNOTA, SEQUENCIA, DHOCOR, HRACT, OCORRENCIAS, DIGITADO, CODUSU) 
	VALUES (@NUNOTA, 0, CAST(GETDATE() AS DATE), CAST(DATEPART(HOUR, GETDATE()) AS VARCHAR(2)) + RIGHT('0' + CAST(DATEPART(MINUTE, GETDATE()) AS VARCHAR(2)), 2) + RIGHT('0' + CAST(DATEPART(SECOND, GETDATE()) AS VARCHAR(2)), 2) ,'Executado procedimento de correção de ICMS interestadual','N', @CODUSU);
END
