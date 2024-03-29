USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_CONTROLEPEDIDO_ALTERARVENDEDOR]    Script Date: 09/05/2018 15:49:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	2016-12-01
	Description:	Permite que um supervisor altere o pedido de um vendedor de sua equipe para outro vendedor.

	Author:			Guilherme Branco Stracini
	Change date:	2017-04-11
	Description:	Adicionado WITH (NOLOCK) nos selects e 
					alterado para permitir que o pedido seja alterado para um vendedor de outra equipe

	Author:			Guilherme Branco Stracini
	Change date:	2018-01-29
	Description:	Permite que usuarios do grupo TI (1) alterem o vendedor tambem

	Author:			Guilherme Branco Stracini
	Change date:	2018-03-01
	Description:	Insere uma mensagem na TSIAVI (Avisos do sistema) para o usuário
					do vendedor saber que o pedido foi alterado para o vendedor dele

	Author:			Guilherme Branco Stracini
	Change date:	2018-05-09
	Description:	Permite que supervisor do call center altere vendedor da loja virtual
					
============================================ */
ALTER PROCEDURE [sankhya].[STP_CONTROLEPEDIDO_ALTERARVENDEDOR] (
       @P_CODUSU INT,
       @P_IDSESSAO VARCHAR(4000),
       @P_QTDLINHAS INT,
       @P_MENSAGEM VARCHAR(4000) OUT
) AS
DECLARE
@PARAM_CODVEND		INT,
@FIELD_ORDERID		VARCHAR(4000),
@FIELD_PEDORIGINAL	INT,
@I					INT,
@APELIDO			VARCHAR(120),
@CODVEND_ANTIGO		INT,
@APELIDO_ANTIGO		VARCHAR(120),
@CODSUPERVISOR		INT,
@TIPVEND			CHAR,
@CODGRUPO			INT,
@NOMEVENDEDOR		VARCHAR(120),
@CODUSUVENDEDOR		INT,
@NUAVISO			INT
BEGIN

	/*
	 * Obtem o código do novo vendedor.
	 */
	SET @PARAM_CODVEND = sankhya.ACT_INT_PARAM(@P_IDSESSAO, 'CODVEND');


	/*
	 * Obtem o apelido do novo vendedor
	 */
	SELECT	@APELIDO = APELIDO 
	FROM TGFVEN WITH (NOLOCK)
	WHERE CODVEND = @PARAM_CODVEND;

	/*
	 * Obtem os dados de quem está alterando (o suposto supervisor) - através do código do parceiro
	 */

	SELECT	@CODSUPERVISOR = V.CODVEND, 
			@TIPVEND = V.TIPVEND,
			@CODGRUPO = U.CODGRUPO
	FROM TSIUSU AS U WITH (NOLOCK)
	INNER JOIN TGFVEN AS V WITH (NOLOCK)
	ON U.CODPARC = V.CODPARC
	WHERE	U.CODUSU = @P_CODUSU
	AND		V.TIPVEND = 'S';
	
	
	/*
	 * Caso não encontre pelo código do parceiro, tenta-se pelo código do vendedor
	 */

	IF @CODSUPERVISOR IS NULL
	BEGIN

			SELECT	@CODSUPERVISOR = V.CODVEND, 
					@TIPVEND = V.TIPVEND,
					@CODGRUPO = U.CODGRUPO
			FROM TSIUSU AS U WITH (NOLOCK)
			INNER JOIN TGFVEN AS V WITH (NOLOCK)
			ON U.CODVEND = V.CODVEND
			wHERE U.CODUSU = @P_CODUSU
			AND V.TIPVEND = 'S' 
			AND U.CODVEND > 0;
	END



	/*
	 * Verifica se quem está alterando é de fato um supervisor, caso contrário lança erro
	 */

	IF @CODGRUPO != 1 AND (@TIPVEND IS NULL OR @TIPVEND != 'S')
	BEGIN	
		RAISERROR('Seu vendedor precisa ser supervisor para alterar o vendedor de um pedido', 16, 1);
		RETURN
	END

	/*
	 * Loop para cada pedido selecionado na tela
	 */
	SET @I = 1
	WHILE @I <= @P_QTDLINHAS
	BEGIN

		/*
		 * Obtem os dados do pedido atual
		 */
		SET @FIELD_ORDERID = sankhya.ACT_TXT_FIELD(@P_IDSESSAO, @I, 'ORDERID')
        SET @FIELD_PEDORIGINAL = sankhya.ACT_INT_FIELD(@P_IDSESSAO, @I, 'PEDORIGINAL')

		/*
		 * Obtem os dados do vendedor antigo/atual (Código, Apelido)
		 */

		SELECT	@CODVEND_ANTIGO = P.CODVEND, @APELIDO_ANTIGO = V.APELIDO 
		FROM	AD_PEDIDOVTEXSC AS P WITH (NOLOCK)
				INNER JOIN TGFVEN AS V WITH (NOLOCK) ON (V.CODVEND = P.CODVEND)
		WHERE	P.ORDERID = @FIELD_ORDERID
				AND P.PEDORIGINAL = @FIELD_PEDORIGINAL;

		/*
		 * Verifica se o vendedor antigo/atual pertence a equipe do supervisor que está alterando.
		 * Se não pertencer lança erro
		 */

		IF @CODGRUPO != 1 
		AND  NOT EXISTS(SELECT 1 FROM TGFVEN WITH (NOLOCK) WHERE AD_CODSUPERVISOR = @CODSUPERVISOR AND CODVEND = @CODVEND_ANTIGO)
		AND @CODVEND_ANTIGO != 22
		BEGIN
			RAISERROR('O vendedor atual (%i - %s) do pedido %i não pertence a sua equipe, não é possível alterar o vendedor deste pedido!', 16, 1, @CODVEND_ANTIGO, @APELIDO_ANTIGO, @FIELD_PEDORIGINAL);
			RETURN
		END

		/*
		 * Obtém os dados do vendedor (parceiro, código de usuário) para mandar o aviso
		 */
		SELECT TOP 1 @NOMEVENDEDOR = V.APELIDO, @CODUSUVENDEDOR = U.CODUSU
		FROM TGFVEN AS V WITH (NOLOCK)
		INNER JOIN TSIUSU AS U WITH (NOLOCK)
		ON V.CODPARC = U.CODPARC
		WHERE V.CODVEND = @PARAM_CODVEND
		AND V.CODPARC != 0;


		/*
		 * Atualiza na TGFCAB o código do vendedor somente nas TOPs de pedidos.
		 * A trigger TRG_UPD_TGFCAB_AD_PEDIDOVTEXSCFLUXO já atualiza as outras notas e na controle de pedidos!
		 */

		UPDATE TGFCAB 
		SET CODVEND = @PARAM_CODVEND 
		WHERE AD_PEDORIGINAL = @FIELD_PEDORIGINAL
		AND (AD_CODREENVIO = 0 OR AD_CODREENVIO IS NULL)
		AND CODTIPOPER IN (500, 501, 502, 503, 515);

		/*
		 * Pega o código do próximo aviso
		 */
		 SELECT @NUAVISO = ULTCOD + 1 FROM TGFNUM WHERE ARQUIVO = 'TSIAVI'; 

		 		/*
		 * Insere um aviso para o novo vendedor saber que o pedido teve o vendedor atualizado para o vendedor dele
		 * somente se o vendedor possuir um código de usuário
		 */

		IF @CODUSUVENDEDOR IS NOT NULL 
			INSERT INTO TSIAVI (NUAVISO, CODUSU, CODUSUREMETENTE, DESCRICAO, DHCRIACAO, IDENTIFICADOR, IMPORTANCIA, TIPO, TITULO)
			VALUES (@NUAVISO + 1, @CODUSUVENDEDOR, @P_CODUSU, 'Olá ' + RTRIM(LTRIM(@NOMEVENDEDOR)) + ' o pedido ' + CAST(@FIELD_PEDORIGINAL AS VARCHAR) + ' foi alterado para o seu vendedor', GETDATE(), 'PERSONALIZADO', 3, 'P', 'Alteração de vendedor');

		/*
		 * Atualiza a TGFNUM com o código usado
		 */
		UPDATE TGFNUM SET ULTCOD = @NUAVISO WHERE ARQUIVO = 'TSIAVI';
		
		/*
		 * Continua o loop...
		 */
		SET @I = @I + 1
	END
	   
	/*
	 * Informa ao supervisor a quantidade de pedidos que foram alterados e qual o código/apelido do novo vendedor.
	 */
	SET @P_MENSAGEM = 'Vendedor do pedido alterado para ' + CAST(@PARAM_CODVEND AS VARCHAR) 
	+ ' - ' + RTRIM(LTRIM(@APELIDO)) + ' em ' + CAST(@P_QTDLINHAS AS VARCHAR) + ' pedidos';
END
