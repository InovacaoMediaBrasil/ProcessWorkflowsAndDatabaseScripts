USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_TGFCAB_ERRO_REMOVER_ENTIDADE]    Script Date: 04/05/2018 15:34:10 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	2018-05-04
	Description:	Permite corrigir problemas com RESERVADO (TGFEST) na removação/alteração de notas pelos Portais do Sankhya-W

	=============================================*/
ALTER PROCEDURE [sankhya].[STP_TGFCAB_ERRO_REMOVER_ENTIDADE] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
DECLARE
       @FIELD_NUNOTA		INT,
       @I					INT,
	   @OCORRENCIA			VARCHAR(2500),
	   @OCORRENCIA_ORIGINAL	VARCHAR(2500),
	   @CODPROD				INT,
	   @QUANTIDADE			FLOAT,
	   @INICIO				INT,
	   @TAMANHO				INT,
	   @PADRAO				VARCHAR(200)
BEGIN
		-- Os valores informados pelo formulário de parâmetros, podem ser obtidos com as funções:
		--     ACT_INT_PARAM
		--     ACT_DEC_PARAM
		--     ACT_TXT_PARAM
		--     ACT_DTA_PARAM
		-- Estas funções recebem 2 argumentos:
		--     ID DA SESSÃO - Identificador da execução (Obtido através de P_IDSESSAO))
		--     NOME DO PARAMETRO - Determina qual parametro deve se deseja obter.

		SET @FIELD_NUNOTA = 0;
		SET @CODPROD = 0;

		SET @I = 1 -- A variável "I" representa o registro corrente.
		WHILE @I <= @P_QTDLINHAS -- Este loop permite obter o valor de campos dos registros envolvidos na execução.
		BEGIN
			-- Para obter o valor dos campos utilize uma das seguintes funções:
			--     ACT_INT_FIELD (Retorna o valor de um campo tipo NUMÉRICO INTEIRO))
			--     ACT_DEC_FIELD (Retorna o valor de um campo tipo NUMÉRICO DECIMAL))
			--     ACT_TXT_FIELD (Retorna o valor de um campo tipo TEXTO),
			--     ACT_DTA_FIELD (Retorna o valor de um campo tipo DATA)
			-- Estas funções recebem 3 argumentos:
			--     ID DA SESSÃO - Identificador da execução (Obtido através do parâmetro P_IDSESSAO))
			--     NÚMERO DA LINHA - Relativo a qual linha selecionada.
			--     NOME DO CAMPO - Determina qual campo deve ser obtido.
			SET @FIELD_NUNOTA = SANKHYA.ACT_INT_FIELD(@P_IDSESSAO, @I, 'NUNOTA')
		   	   
			SET @PADRAO = '%Valor de reserva negativo(-%';
			SELECT @OCORRENCIA = OCORRENCIAS FROM sankhya.TGFACT WHERE NUNOTA = @FIELD_NUNOTA AND OCORRENCIAS LIKE @PADRAO;
			
			IF @OCORRENCIA IS NULL
			BEGIN
				SET @I = @I + 1;
				CONTINUE;
			END

			SET @OCORRENCIA_ORIGINAL = @OCORRENCIA;

			SET @INICIO = PATINDEX(@PADRAO, @OCORRENCIA);
			SET @OCORRENCIA = SUBSTRING(@OCORRENCIA, @INICIO + LEN(@PADRAO) - 2, LEN(@OCORRENCIA));
			SET @TAMANHO = PATINDEX('%)%', @OCORRENCIA);
			SET @QUANTIDADE = CAST(SUBSTRING(@OCORRENCIA, 0, @TAMANHO) AS FLOAT);
			SET @PADRAO = '%para o produto: %';
			SET @INICIO = PATINDEX(@PADRAO, @OCORRENCIA);
			SET @CODPROD = CAST(SUBSTRING(@OCORRENCIA, @INICIO + LEN(@PADRAO) - 2, LEN(@OCORRENCIA)) AS INT);

			IF EXISTS (SELECT 1 FROM sankhya.TGFEST WITH (NOLOCK) WHERE CODPROD = @CODPROD)
				UPDATE sankhya.TGFEST SET RESERVADO = RESERVADO + @QUANTIDADE WHERE CODPROD = @CODPROD;
			ELSE
				INSERT INTO sankhya.TGFEST (CODPROD, CODEMP, CONTROLE, CODLOCAL, TIPO, ESTOQUE, RESERVADO)
				VALUES (@CODPROD, 1, '', 0, 'P', @QUANTIDADE, @QUANTIDADE);

			DELETE FROM sankhya.TGFACT WHERE NUNOTA = @FIELD_NUNOTA AND OCORRENCIAS LIKE @OCORRENCIA_ORIGINAL;
			SET @I = @I + 1
       END
	   
	   SET @P_MENSAGEM = 'Problema de estoque corrigido para a nota ' + CAST(@FIELD_NUNOTA AS VARCHAR) + ' no produto ' + CAST(@CODPROD AS VARCHAR);
END
