USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_CORRIGE_PLP_VENCIDA]    Script Date: 09/04/2018 17:56:57 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	2018-05-06
	Description:	Procedimento utilizado pela logística quando um pedido volta dos Correios com PLP vencida.
					Cancela o envio atual (AD_CPENVIOS), muda a transportadora (provalvemente está Mercado Envios)
					e gera uma nova etiqueta
	============================================= */
ALTER PROCEDURE [sankhya].[STP_CORRIGE_PLP_VENCIDA] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
DECLARE	@FIELD_NUNOTA INT, -- NUNOTA atual
		@I INT, -- O total de linhas selecionadas
		@G INT, -- O total de etiquetas geradas
		@ORDERID VARCHAR(250),
		@PEDORIGINAL INT,
		@CODMODTRANSP INT,
		@CODTIPOPER INT
BEGIN 
	SET @G = 0; -- Nenhuma etiqueta gerada até o momento
	SET @I = 1;-- A variável "I" representa o registro corrente.
	WHILE @I <= @P_QTDLINHAS -- Este loop permite obter o valor de campos dos registros envolvidos na execução.
	BEGIN
		SET @FIELD_NUNOTA = SANKHYA.ACT_INT_FIELD(@P_IDSESSAO, @I, 'NUNOTA');

		/* Incrementa o contador de itens percoridos/selecionados*/
		SET @I = @I + 1;

		/*
		 * Obtém os dados da nota que está com a PLP vencida, desde que a nota seja da TOP 550
		 * Obtém os paramêtros da procedure (pedido original, order identifier, código modalidade de transporte, código do tipo de operação)
		 */
		SELECT	@PEDORIGINAL = F.PEDORIGINAL,
				@ORDERID = F.ORDERID,
				@CODMODTRANSP =  C.AD_IDMOD,
				@CODTIPOPER = C.CODTIPOPER
		FROM sankhya.TGFCAB AS C WITH (NOLOCK)
		INNER JOIN sankhya.AD_PEDIDOVTEXSCFLUXO AS F WITH (NOLOCK)
		ON F.NUNOTA = C.NUNOTA
		WHERE C.NUNOTA = @FIELD_NUNOTA;
		

		/*
		 * Se o order identifier estiver nulo, e existir a NUNOTA na tabela de fluxos reenvios, pega os dados de lá
		 */
		IF @ORDERID IS NULL 
			SELECT	@ORDERID = F.ORDERID, 
					@PEDORIGINAL = F.PEDORIGINAL, 
					@CODMODTRANSP = C.AD_IDMOD,
					@CODTIPOPER = C.CODTIPOPER
			FROM sankhya.TGFCAB AS C WITH (NOLOCK)
			INNER JOIN sankhya.AD_PEDIDOVTEXSCREENVIOFLUXO AS F WITH (NOLOCK)
			ON F.NUNOTA = C.NUNOTA
			WHERE C.NUNOTA = @FIELD_NUNOTA;

		/*
		 * Se o order identifier permanecer nulo (não existe a nunota nem na Fluxo e nem na Fluxo Reenvio)
		 * lança execeção informando o usuário que não é possível gerar a etiqueta
		 */
		IF @ORDERID IS NULL
		BEGIN
			RAISERROR('Não foi possível localizar o fluxo da nota na tabela de fluxos e nem na de fluxos reenvios', 16, 1);
			RETURN;
		END
			
		/*
		 * Se não for uma nota de venda (TOP 550) gera erro
		 */
		IF @CODTIPOPER IS NULL OR @CODTIPOPER != 550
		BEGIN
			RAISERROR('Só é possível gerar etiquetas para notas da TOP 550.<br /><br /> Nota de número único %i - TOP %i', 16, 1, @FIELD_NUNOTA, @CODTIPOPER);
			RETURN;
		END;

		/*
		 * Verifica se a modalidade de envio permite correção (Somente pedidos do Mercado Livre podem ser corrigidos, só eles geram PLP)
		 */
		
		IF @CODMODTRANSP NOT IN (9, 12)
		BEGIN
			RAISERROR('Só é possível corrigir etiquetas com PLP vencida se a modalidade de envio for Mercado Envios (Códigos 9 e 12). Pedido %i com modalidade de envio: %i', 16, 1, @PEDORIGINAL, @CODMODTRANSP);
			RETURN;
		END	

		SET @CODMODTRANSP = (CASE WHEN @CODMODTRANSP = 9 THEN 3 ELSE 4 END);

		/*
		 * Atualiza a forma de envio, se for 9 (Mercado Envios - PAC) vai pra 3 (PAC), se for 12 (Mercado Envios - Sedex) vai pra 4 (Sedex)
		 */
		 UPDATE sankhya.TGFCAB
		 SET AD_IDMOD = @CODMODTRANSP
		 WHERE AD_PEDORIGINAL = @PEDORIGINAL;


		/*
	     * Marca como PLP vencida etiqueta atual
		 */
		 UPDATE sankhya.AD_CPENVIOS
		 SET STATUS = 'V'
		 WHERE NUNOTA = @FIELD_NUNOTA
		 AND [STATUS] IN ('N', 'T');
		 

		/*
		 * Chama a procedure que gera a etiqueta com os paramêtros corretos
		 */	
		EXEC STP_GERAR_ETIQUETA_TRANSPORTADORA @NUNOTA = @FIELD_NUNOTA, @PEDORIGINAL = @PEDORIGINAL, @ORDERID = @ORDERID, @CODMODTRANSP = @CODMODTRANSP
		
		/* Aumenta em um a contagem de etiquetas geradas */
		SET @G = @G + 1;
	END
	SET @I = @I - 1;
	SET @P_MENSAGEM = 'Foram geradas ' + CAST(@G AS VARCHAR) + ' etiquetas de ' + CAST(@I AS VARCHAR) + ' notas selecionadas';
END
