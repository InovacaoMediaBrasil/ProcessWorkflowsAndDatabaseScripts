DECLARE 
@INFO VARCHAR(100),
@IDEXP INT,
@IDMOD INT,
@SALDO INT,
@MODALIDADE VARCHAR(20),
@SUBJECT VARCHAR(200),
@DESTINOS VARCHAR(MAX);

SET @DESTINOS = 'logistica@editorainovacao.com.br;ti@editorainovacao.com.br;help@editorainovacao.com.br;';

DECLARE cursorEtiquetas CURSOR FAST_FORWARD FOR
SELECT E.IDEXP, E.IDMOD, E.SALDO, M.DECRMODTRANS
FROM sankhya.AD_EXPEDICAO AS E WITH (NOLOCK)
INNER JOIN sankhya.AD_MODTRANSPORTE AS M ON M.IDMOD = E.IDMOD
WHERE SEQATUAL = 'S'
ORDER BY M.DECRMODTRANS

OPEN cursorEtiquetas;

FETCH NEXT FROM cursorEtiquetas INTO @IDEXP, @IDMOD, @SALDO, @MODALIDADE;

WHILE @@FETCH_STATUS = 0
BEGIN
	IF @SALDO < 1200 AND NOT EXISTS(SELECT 1 FROM sankhya.AD_EXPEDICAO WITH (NOLOCK) WHERE IDMOD = @IDMOD AND IDEXP > @IDEXP)
	BEGIN
		SET @SUBJECT = '[URGENTE] O range de etiquetas [' + @MODALIDADE + '] está acabando!';
		SET @INFO = 'Solicitar novo range de etiquetas ' + @MODALIDADE + ' nos Correios. O sistema tem disponível apenas: ' + CAST(@SALDO AS VARCHAR);
		EXEC msdb.dbo.sp_send_dbmail
			@profile_name = 'SQLAlerts',
			@recipients = @DESTINOS,
			@body = @INFO,
			@subject = @SUBJECT
	END
	
	FETCH NEXT FROM cursorEtiquetas INTO @IDEXP, @IDMOD, @SALDO, @MODALIDADE;
END;
CLOSE cursorEtiquetas;
DEALLOCATE cursorEtiquetas;