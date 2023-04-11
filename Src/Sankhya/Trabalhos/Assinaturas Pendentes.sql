DECLARE 
@QTD INT,
@INFO VARCHAR(100),
@TODAY AS VARCHAR(10),
@SUBJECT AS VARCHAR(25)

SELECT @QTD = COUNT(*) 
FROM sankhya.TGFCAB AS CAB WITH (NOLOCK)
INNER JOIN sankhya.TGFITE AS ITE WITH (NOLOCK)
ON ITE.NUNOTA = CAB.NUNOTA
INNER JOIN sankhya.TGFPRO AS PROD WITH (NOLOCK)
ON PRO.CODPROD = ITE.CODPROD
WHERE PRO.CODGRUPOPROD BETWEEN 500000 AND 599999
AND PROD.AD_DTENTREGA <= GETDATE()
AND ITE.QTDENTREGUE < ITE.QTDNEG 
AND CAB.CODTIPOER = 508

IF @QTD = 0
	RETURN;
	
SET @TODAY = CONVERT(VARCHAR, GETDATE(), 103);
SET @SUBJECT = 'Mala Direta [' + @TODAY + ']';
SET @INFO = 'Hoje, dia' + @TODAY + 'existe ' + CAST(@QTD AS VARCHAR) + ' revistas para serem enviadas como Mala Direta.';

EXEC msdb.dbo.sp_send_dbmail
		@profile_name = 'SQLAlerts',
		@from_address = 'suporte@editorainovacao.com.br',
		@recipients = 'logistica@editorainovacao.com.br',
		@copy_recipients = 'suporte@editorainovacao.com.br',
		@body = @INFO,
		@subject = @SUBJECT