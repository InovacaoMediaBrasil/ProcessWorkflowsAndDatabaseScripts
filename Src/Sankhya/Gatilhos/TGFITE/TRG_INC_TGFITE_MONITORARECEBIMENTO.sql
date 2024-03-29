USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_TGFITE_MONITORARECEBIMENTO]    Script Date: 17/04/2018 12:21:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	2017-05-16
	Description:	Insere um aviso (TSIAVI) quando é dada a entrada de uma nota de compra e o produto está em monitoramento
					Regras: nota (TGFCAB) com o campo TIPMOV com valor C (C-Compra) e para o produto (TGFPRO) com a flag AD_MONITRECEB com valor S

	Author:			Guilherme Branco Stracini
	Create date:	2018-04-17
	Description:	Corrigido problema quando o ULTCOD dá erro gerando duplicado
	============================================= */
ALTER TRIGGER [sankhya].[TRG_INC_TGFITE_MONITORARECEBIMENTO] 
   ON  [sankhya].[TGFITE] 
   AFTER INSERT
AS 
DECLARE
	@NUNOTA INT,
	@NUAVI INT,
	@CODPROD INT,
	@CODUSU INT,
	@NOMEPARC VARCHAR(255)
BEGIN
	SET NOCOUNT ON;

	/*
	 * Obtém os dados do item inserido na TGFITE (NUNOTA, CODPROD e CODUSU)
	 */
	SELECT	@NUNOTA =	NUNOTA, 
			@CODPROD =	CODPROD, 
			@CODUSU =	CODUSU
	FROM INSERTED;

	/*
	 * Verifica se a nota (NUNOTA) é do TIPMOV C (C-Compra) na TGFCAB, caso não seja encerra o gatilho
	 */

	IF NOT EXISTS (SELECT 1 FROM TGFCAB WITH (NOLOCK) WHERE NUNOTA = @NUNOTA AND TIPMOV = 'C')
		RETURN;

	/*
	 * Verifica se o produto (CODPROD) está com a flag AD_MONITRECEB (Monitora recebimento) ativada, se não estiver encerra o gatilho
	 */

	IF NOT EXISTS (SELECT 1 FROM TGFPRO WITH (NOLOCK) WHERE CODPROD = @CODPROD AND AD_MONITRECEB = 'S')
		RETURN;

	/*
	 * Obtém o nome real (TGFPAR) do usuário que efetuou o INSERT da nota para informar no aviso/notificação.
	 */

	SELECT @NOMEPARC = P.NOMEPARC
	FROM TGFPAR AS P WITH (NOLOCK)
	INNER JOIN TSIUSU AS U WITH (NOLOCK)
	ON P.CODPARC = U.CODPARC
	WHERE U.CODUSU = @CODUSU;

	
	/*
	 * Obtém o próximo código da TSIAVI
	 */
	SELECT @NUAVI = N.ULTCOD + 1
	FROM TGFNUM AS N
	WHERE ARQUIVO = 'TSIAVI';

	/*
	 * Atualiza o código na TSIAVI
	 */	
	UPDATE TGFNUM
	SET ULTCOD = @NUAVI
	WHERE ARQUIVO = 'TSIAVI';

	/*
	 * Insere um aviso na TSIAVI para que os usuários do grupo 18 (Comercial-Cadastro) recebam uma notificação no sistema
	 * A notificação informa o código do produto, número da nota e quem efetuou a baixa (recebimento) da nota no sistema
	 */

	INSERT INTO TSIAVI (NUAVISO, CODGRUPO, CODUSUREMETENTE, DESCRICAO, DHCRIACAO, IDENTIFICADOR, IMPORTANCIA, TIPO, TITULO)
	VALUES (@NUAVI, 18, 0, 'O produto ' + CAST(@CODPROD AS VARCHAR) + ' foi recebido pela nota ' + CAST(@NUNOTA AS VARCHAR) + 
	'.Entrada efetuada pelo usuário ' + CAST(@CODUSU AS VARCHAR) + ' - ' + @NOMEPARC, GETDATE(), 'PERSONALIZADO', 3, 'P', 'Produto monitorado recebido')
END
